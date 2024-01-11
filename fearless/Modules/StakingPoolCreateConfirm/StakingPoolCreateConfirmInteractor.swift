import UIKit
import RobinHood
import SSFModels

// swiftlint:disable opening_brace multiple_closures_with_trailing_closure
final class StakingPoolCreateConfirmInteractor {
    private let priceLocalSubscriber: PriceLocalStorageSubscriber

    // MARK: - Private properties

    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private weak var output: StakingPoolCreateConfirmInteractorOutput?
    private let chainAsset: ChainAsset
    private let callFactory: SubstrateCallFactoryProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let createData: StakingPoolCreateData
    private let signingWrapper: SigningWrapperProtocol
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        createData: StakingPoolCreateData,
        signingWrapper: SigningWrapperProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        chainAsset = createData.chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriber = priceLocalSubscriber
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.createData = createData
        self.signingWrapper = signingWrapper
        self.callFactory = callFactory
    }

    private var feeReuseIdentifier: String? {
        let rootRequest = chainAsset.chain.accountRequest()
        let nominatorRequest = chainAsset.chain.accountRequest()
        let bouncerRequest = chainAsset.chain.accountRequest()
        let precision = Int16(chainAsset.asset.precision)

        guard
            let substrateAmountValue = createData.amount.toSubstrateAmount(precision: precision),
            let rootAccount = createData.root.fetch(for: rootRequest)?.accountId,
            let nominationAccount = createData.nominator.fetch(for: nominatorRequest)?.accountId,
            let bouncerAccount = createData.bouncer.fetch(for: bouncerRequest)?.accountId
        else {
            return nil
        }

        let createPool = callFactory.createPool(
            amount: substrateAmountValue,
            root: .accoundId(rootAccount),
            nominator: .accoundId(nominationAccount),
            bouncer: .accoundId(bouncerAccount)
        )

        return createPool.callName
    }

    private var feeBuilderClosure: ExtrinsicBuilderClosure? {
        let rootRequest = chainAsset.chain.accountRequest()
        let nominatorRequest = chainAsset.chain.accountRequest()
        let bouncerRequest = chainAsset.chain.accountRequest()
        let precision = Int16(chainAsset.asset.precision)

        guard
            let substrateAmountValue = createData.amount.toSubstrateAmount(precision: precision),
            let rootAccount = createData.root.fetch(for: rootRequest)?.accountId,
            let nominationAccount = createData.nominator.fetch(for: nominatorRequest)?.accountId,
            let bouncerAccount = createData.bouncer.fetch(for: bouncerRequest)?.accountId,
            let metadata = createData.poolName.data(using: .ascii)
        else {
            return nil
        }

        let createPool = callFactory.createPool(
            amount: substrateAmountValue,
            root: .accoundId(rootAccount),
            nominator: .accoundId(nominationAccount),
            bouncer: .accoundId(bouncerAccount)
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
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
        subscribeToPoolMembers()
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

extension StakingPoolCreateConfirmInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
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
