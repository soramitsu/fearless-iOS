import Foundation
import RobinHood
import SoraKeystore
import SSFUtils
import BigInt
import SSFModels
import SSFRuntimeCodingService

protocol StakingRedeemConfirmationPoolStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didSubmitRedeeming(result: Result<String, Error>)
    func didReceiveSlashingSpans(result: Result<SlashingSpans?, Error>)
    func didReceiveStakeInfo(result: Result<StakingPoolMember?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)
}

final class StakingRedeemConfirmationPoolStrategy: RuntimeConstantFetching, AccountFetching {
    weak var output: StakingRedeemConfirmationPoolStrategyOutput?
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let engine: JSONRPCEngine
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let keystore: KeystoreProtocol
    private let eventCenter: EventCenterProtocol
    private let slashesOperationFactory: SlashesOperationFactoryProtocol
    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol

    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    init(
        output: StakingRedeemConfirmationPoolStrategyOutput?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol,
        eventCenter: EventCenterProtocol,
        slashesOperationFactory: SlashesOperationFactoryProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.engine = engine
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.keystore = keystore
        self.output = output
        self.signingWrapper = signingWrapper
        self.eventCenter = eventCenter
        self.slashesOperationFactory = slashesOperationFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
    }

    private func fetchSlashingSpansForStash(
        _ stash: AccountAddress
    ) {
        let wrapper = slashesOperationFactory.createSlashingSpansOperationForStash(
            stash,
            engine: engine,
            runtimeService: runtimeService,
            chainAsset: chainAsset
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                if let result = wrapper.targetOperation.result {
                    self?.output?.didReceiveSlashingSpans(result: result)
                } else {
                    self?.output?.didReceiveSlashingSpans(result: .failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        operationManager.enqueue(
            operations: wrapper.allOperations,
            in: .transient
        )
    }
}

extension StakingRedeemConfirmationPoolStrategy: StakingRedeemConfirmationStrategy {
    func setup() {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
            poolMemberProvider = subscribeToPoolMembers(for: accountId, chainAsset: chainAsset)
        }

        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            fetchSlashingSpansForStash(address)
        }

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.output?.didReceiveExistentialDeposit(result: result)
        }

        feeProxy.delegate = self
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let extrinsicService = extrinsicService,
              let builderClosure = builderClosure,
              let reuseIdentifier = reuseIdentifier else {
            output?.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper,
            let builderClosure = builderClosure else {
            output?.didSubmitRedeeming(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.output?.didSubmitRedeeming(result: result)

            self?.eventCenter.notify(with: StakingUpdatedEvent())
        }
    }
}

extension StakingRedeemConfirmationPoolStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingRedeemConfirmationPoolStrategy: AnyProviderAutoCleaning {}

extension StakingRedeemConfirmationPoolStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension StakingRedeemConfirmationPoolStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handlePoolMember(result: Result<StakingPoolMember?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveStakeInfo(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveActiveEra(result: result)
    }
}
