import UIKit
import RobinHood

final class StakingPoolCreateInteractor {
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private weak var output: StakingPoolCreateInteractorOutput?
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let callFactory = SubstrateCallFactory()
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
        existentialDepositService: ExistentialDepositServiceProtocol
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
    }

    // MARK: - Private methods

    private var feeReuseIdentifier: String? {
        let request = chainAsset.chain.accountRequest()

        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ),
            let rootAccount = wallet.fetch(for: request)?.accountId
        else {
            return nil
        }

        let createPool = callFactory.createPool(
            amount: amount,
            root: .accoundId(rootAccount),
            nominator: .accoundId(rootAccount),
            stateToggler: .accoundId(rootAccount)
        )

        return createPool.callName
    }

    private var builderClosure: ExtrinsicBuilderClosure? {
        let request = chainAsset.chain.accountRequest()

        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ),
            let rootAccount = wallet.fetch(for: request)?.accountId
        else {
            return nil
        }

        let joinPool = callFactory.createPool(
            amount: amount,
            root: .accoundId(rootAccount),
            nominator: .accoundId(rootAccount),
            stateToggler: .accoundId(rootAccount)
        )

        return { builder in
            try builder.adding(call: joinPool)
        }
    }

    private func fetchRuntimeData() {
        let minCreateBondOperation = stakingPoolOperationFactory.fetchMinCreateBondOperation()
        minCreateBondOperation.targetOperation.completionBlock = { [weak self] in
            let minCreateBond = try? minCreateBondOperation.targetOperation.extractNoCancellableResultData()
            self?.output?.didReceiveMinBond(minCreateBond)
        }

        operationManager.enqueue(operations: minCreateBondOperation.allOperations, in: .transient)
    }

    private func fetchPoolMembers() {
        let accountRequest = chainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: accountRequest)?.accountId else {
            return
        }

        let poolMembersOperation = stakingPoolOperationFactory.fetchStakingPoolMembers(accountId: accountId)
        poolMembersOperation.targetOperation.completionBlock = { [weak self] in
            let poolMember = try? poolMembersOperation.targetOperation.extractNoCancellableResultData()
            self?.output?.didReceivePoolMember(poolMember)
        }

        operationManager.enqueue(operations: poolMembersOperation.allOperations, in: .transient)
    }

    private func fetchLastPoolId() {
        let lastPoolIdOperation = stakingPoolOperationFactory.fetchLastPoolId()
        lastPoolIdOperation.targetOperation.completionBlock = { [weak self] in
            let lastPoolId = try? lastPoolIdOperation.targetOperation.extractNoCancellableResultData()
            DispatchQueue.main.async {
                self?.output?.didReceiveLastPoolId(lastPoolId)
            }
        }

        operationManager.enqueue(operations: lastPoolIdOperation.allOperations, in: .transient)
    }
}

// MARK: - StakingPoolCreateInteractorInput

extension StakingPoolCreateInteractor: StakingPoolCreateInteractorInput {
    func setup(with output: StakingPoolCreateInteractorOutput) {
        self.output = output
        feeProxy.delegate = self

        fetchPoolMembers()
        fetchLastPoolId()

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
        guard
            let reuseIdentifier = feeReuseIdentifier,
            let builderClosure = builderClosure
        else {
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }
}

extension StakingPoolCreateInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result)
    }
}

extension StakingPoolCreateInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension StakingPoolCreateInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}
