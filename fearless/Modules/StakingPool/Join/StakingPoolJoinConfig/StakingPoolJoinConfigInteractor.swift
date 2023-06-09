import UIKit
import RobinHood
import SSFModels

final class StakingPoolJoinConfigInteractor {
    // MARK: - Private properties

    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private weak var output: StakingPoolJoinConfigInteractorOutput?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let callFactory: SubstrateCallFactoryProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let operationManager: OperationManagerProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.operationManager = operationManager
        self.existentialDepositService = existentialDepositService
        self.callFactory = callFactory
    }

    private var feeReuseIdentifier: String? {
        guard let amount = StakingConstants.maxAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        let joinPool = callFactory.joinPool(poolId: "\(UInt32.max)", amount: amount)

        return joinPool.callName
    }

    private var builderClosure: ExtrinsicBuilderClosure? {
        guard let amount = StakingConstants.maxAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        let joinPool = callFactory.joinPool(poolId: "\(UInt32.max)", amount: amount)

        return { builder in
            try builder.adding(call: joinPool)
        }
    }

    private func fetchRuntimeData() {
        let minJoinBondOperation = stakingPoolOperationFactory.fetchMinJoinBondOperation()
        minJoinBondOperation.targetOperation.completionBlock = { [weak self] in
            let minJoinBond = try? minJoinBondOperation.targetOperation.extractNoCancellableResultData()
            self?.output?.didReceiveMinBond(minJoinBond)
        }

        operationManager.enqueue(operations: minJoinBondOperation.allOperations, in: .transient)
    }
}

// MARK: - StakingPoolJoinConfigInteractorInput

extension StakingPoolJoinConfigInteractor: StakingPoolJoinConfigInteractorInput {
    func setup(with output: StakingPoolJoinConfigInteractorOutput) {
        self.output = output
        feeProxy.delegate = self

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(
                chainAsset: chainAsset,
                accountId: accountId,
                handler: self
            )
        }

        existentialDepositService.fetchExistentialDeposit(chainAsset: chainAsset) { [weak self] result in
            self?.output?.didReceive(existentialDepositResult: result)
        }

        fetchRuntimeData()
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
}

extension StakingPoolJoinConfigInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result)
    }
}

extension StakingPoolJoinConfigInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension StakingPoolJoinConfigInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}
