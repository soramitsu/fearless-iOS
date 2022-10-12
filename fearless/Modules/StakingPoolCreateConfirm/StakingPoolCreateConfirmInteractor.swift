import UIKit
import RobinHood

// swiftlint:disable opening_brace multiple_closures_with_trailing_closure
final class StakingPoolCreateConfirmInteractor {
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private weak var output: StakingPoolCreateConfirmInteractorOutput?
    private let chainAsset: ChainAsset
    private let callFactory = SubstrateCallFactory()
    private let extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let createData: StakingPoolCreateData
    private let signingWrapper: SigningWrapperProtocol
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        createData: StakingPoolCreateData,
        signingWrapper: SigningWrapperProtocol
    ) {
        chainAsset = createData.chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.createData = createData
        self.signingWrapper = signingWrapper
    }

    private var feeReuseIdentifier: String? {
        let rootRequest = chainAsset.chain.accountRequest()
        let nominatorRequest = chainAsset.chain.accountRequest()
        let stateTogglerRequest = chainAsset.chain.accountRequest()
        let precision = Int16(chainAsset.asset.precision)

        guard
            let substrateAmountValue = createData.amount.toSubstrateAmount(precision: precision),
            let rootAccount = createData.root.fetch(for: rootRequest)?.accountId,
            let nominationAccount = createData.nominator.fetch(for: nominatorRequest)?.accountId,
            let stateTogglerAccount = createData.stateToggler.fetch(for: stateTogglerRequest)?.accountId
        else {
            return nil
        }

        let createPool = callFactory.createPool(
            amount: substrateAmountValue,
            root: .accoundId(rootAccount),
            nominator: .accoundId(nominationAccount),
            stateToggler: .accoundId(stateTogglerAccount)
        )

        return createPool.callName
    }

    private var feeBuilderClosure: ExtrinsicBuilderClosure? {
        let rootRequest = chainAsset.chain.accountRequest()
        let nominatorRequest = chainAsset.chain.accountRequest()
        let stateTogglerRequest = chainAsset.chain.accountRequest()
        let precision = Int16(chainAsset.asset.precision)

        guard
            let substrateAmountValue = createData.amount.toSubstrateAmount(precision: precision),
            let rootAccount = createData.root.fetch(for: rootRequest)?.accountId,
            let nominationAccount = createData.nominator.fetch(for: nominatorRequest)?.accountId,
            let stateTogglerAccount = createData.stateToggler.fetch(for: stateTogglerRequest)?.accountId,
            let metadata = createData.poolName.data(using: .ascii)
        else {
            return nil
        }

        let createPool = callFactory.createPool(
            amount: substrateAmountValue,
            root: .accoundId(rootAccount),
            nominator: .accoundId(nominationAccount),
            stateToggler: .accoundId(stateTogglerAccount)
        )

        let setMetadataCall = callFactory.setPoolMetadata(
            poolId: "\(createData.poolId)",
            metadata: metadata
        )

        return { builder in
            try builder.adding(call: createPool).adding(call: setMetadataCall)
        }
    }

    private func subscribeToPoolMembers() {
        let accountRequest = createData.chainAsset.chain.accountRequest()
        guard let accountId = createData.root.fetch(for: accountRequest)?.accountId else {
            return
        }

        poolMemberProvider = subscribeToPoolMembers(
            for: accountId,
            chainAsset: createData.chainAsset
        )
    }
}

// MARK: - StakingPoolCreateConfirmInteractorInput

extension StakingPoolCreateConfirmInteractor: StakingPoolCreateConfirmInteractorInput {
    func setup(with output: StakingPoolCreateConfirmInteractorOutput) {
        self.output = output

        feeProxy.delegate = self

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

//        subscribeToPoolMembers()
    }

    func estimateFee() {
        guard
            let reuseIdentifier = feeReuseIdentifier,
            let builderClosure = feeBuilderClosure
        else {
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }

    func submit() {
        guard let builderClosure = feeBuilderClosure else {
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.output?.didReceive(extrinsicResult: result)
        }
    }
}

extension StakingPoolCreateConfirmInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result)
    }
}

extension StakingPoolCreateConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension StakingPoolCreateConfirmInteractor:
    RelaychainStakingLocalStorageSubscriber,
    RelaychainStakingLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<StakingPoolMember?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceive(stakingPoolMembers: result)
        }
    }
}
