import UIKit
import RobinHood
import SSFModels

final class StakingPoolJoinConfirmInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: StakingPoolJoinConfirmInteractorOutput?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let callFactory: SubstrateCallFactoryProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let amount: Decimal
    private let pool: StakingPool
    private let signingWrapper: SigningWrapperProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        amount: Decimal,
        pool: StakingPool,
        signingWrapper: SigningWrapperProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.amount = amount
        self.pool = pool
        self.signingWrapper = signingWrapper
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.validatorOperationFactory = validatorOperationFactory
        self.callFactory = callFactory
    }

    private var feeReuseIdentifier: String? {
        guard let substrateAmountValue = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            return nil
        }

        let joinPool = callFactory.joinPool(poolId: pool.id, amount: substrateAmountValue)

        return joinPool.callName
    }

    private var builderClosure: ExtrinsicBuilderClosure? {
        guard let substrateAmountValue = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            return nil
        }

        let joinPool = callFactory.joinPool(poolId: pool.id, amount: substrateAmountValue)

        return { builder in
            try builder.adding(call: joinPool)
        }
    }
}

// MARK: - StakingPoolJoinConfirmInteractorInput

extension StakingPoolJoinConfirmInteractor: StakingPoolJoinConfirmInteractorInput {
    func setup(with output: StakingPoolJoinConfirmInteractorOutput) {
        self.output = output
        feeProxy.delegate = self

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        fetchCompoundConstant(
            for: .nominationPoolsPalletId,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Data, Error>) in
            self?.output?.didReceive(palletIdResult: result)
        }
    }

    func estimateFee() {
        guard let reuseIdentifier = feeReuseIdentifier, let builderClosure = builderClosure else {
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }

    func submit() {
        guard let builderClosure = builderClosure else {
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.output?.didReceive(extrinsicResult: result)
        }
    }

    func fetchPoolNomination(poolStashAccountId: AccountId) {
        let nominationOperation = validatorOperationFactory.nomination(accountId: poolStashAccountId)
        nominationOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let nomination = try nominationOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(nomination: nomination)
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: nominationOperation.allOperations, in: .transient)
    }
}

extension StakingPoolJoinConfirmInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result)
    }
}

extension StakingPoolJoinConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
