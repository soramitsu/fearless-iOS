import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils
import SoraFoundation

final class StakingMainInteractor: RuntimeConstantFetching {
    weak var presenter: StakingMainInteractorOutputProtocol?

    var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
        sharedState.relaychainStakingLocalSubscriptionFactory
    }

    var parachainStakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol {
        sharedState.parachainStakingLocalSubscriptionFactory
    }

    var stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol {
        sharedState.stakingAnalyticsLocalSubscriptionFactory
    }

    var stakingSettings: StakingAssetSettings { sharedState.settings }

    let selectedWalletSettings: SelectedWalletSettings
    let sharedState: StakingSharedState
    let chainRegistry: ChainRegistryProtocol
    let stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingServiceFactory: StakingServiceFactoryProtocol
    let accountProviderFactory: AccountProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol
    var eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol?
    let applicationHandler: ApplicationHandlerProtocol
    let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    let commonSettings: SettingsManagerProtocol

    let logger: LoggerProtocol?
    var collatorOperationFactory: ParachainCollatorOperationFactory

    var selectedAccount: ChainAccountResponse?
    var selectedChainAsset: ChainAsset?

    private var chainSubscriptionId: UUID?
    private var accountSubscriptionId: UUID?

    var priceProvider: AnySingleValueProvider<PriceData>?
    var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    var stashControllerProvider: StreamableProvider<StashItem>?
    var validatorProvider: AnyDataProvider<DecodedValidator>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    var payeeProvider: AnyDataProvider<DecodedPayee>?
    var controllerAccountProvider: StreamableProvider<MetaAccountModel>?
    var minNominatorBondProvider: AnyDataProvider<DecodedBigUInt>?
    var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    var rewardAnalyticsProvider: AnySingleValueProvider<[SubqueryRewardItemData]>?
    var delegatorStateProvider: AnyDataProvider<DecodedParachainDelegatorState>?
    var collatorIds: [AccountId]?

    init(
        selectedWalletSettings: SelectedWalletSettings,
        sharedState: StakingSharedState,
        chainRegistry: ChainRegistryProtocol,
        stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingServiceFactory: StakingServiceFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationManager: OperationManagerProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        commonSettings: SettingsManagerProtocol,
        logger: LoggerProtocol? = nil,
        collatorOperationFactory: ParachainCollatorOperationFactory
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.sharedState = sharedState
        self.chainRegistry = chainRegistry
        self.stakingRemoteSubscriptionService = stakingRemoteSubscriptionService
        self.stakingAccountUpdatingService = stakingAccountUpdatingService
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingServiceFactory = stakingServiceFactory
        self.accountProviderFactory = accountProviderFactory
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.applicationHandler = applicationHandler
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.commonSettings = commonSettings
        self.logger = logger
        self.collatorOperationFactory = collatorOperationFactory
        eventCenter.add(observer: self, dispatchIn: .main)
    }

    deinit {
        if let selectedChainAsset = selectedChainAsset {
            clearChainRemoteSubscription(for: selectedChainAsset.chain.chainId)
        }

        clearAccountRemoteSubscription()
    }

    func setupSelectedAccountAndChainAsset() {
        guard
            let wallet = selectedWalletSettings.value,
            let chainAsset = stakingSettings.value,
            let response = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return
        }

        selectedAccount = response
        selectedChainAsset = chainAsset
    }

    func updateSharedState() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = selectedChainAsset,
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        else {
            return
        }

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        let rewardOperationFactory = RewardOperationFactory.factory(blockExplorer: chainAsset.chain.externalApi?.staking)

        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: identityOperationFactory,
            subqueryOperationFactory: rewardOperationFactory
        )

        self.collatorOperationFactory = collatorOperationFactory

        do {
            let eraValidatorService = try stakingServiceFactory.createEraValidatorService(
                for: chainAsset.chain
            )

            let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
                for: chainAsset,
                assetPrecision: Int16(chainAsset.asset.precision),
                validatorService: eraValidatorService,
                collatorOperationFactory: collatorOperationFactory
            )

            sharedState.eraValidatorService.throttle()
            sharedState.rewardCalculationService.throttle()

            sharedState.replaceEraValidatorService(eraValidatorService)
            sharedState.replaceRewardCalculatorService(rewardCalculatorService)

            eraValidatorService.setup()
            rewardCalculatorService.setup()
        } catch {
            logger?.error("Couldn't create shared state")
        }
    }

    func clearChainRemoteSubscription(for chainId: ChainModel.Id) {
        if let chainSubscriptionId = chainSubscriptionId {
            stakingRemoteSubscriptionService.detachFromGlobalData(
                for: chainSubscriptionId,
                chainId: chainId,
                queue: nil,
                closure: nil,
                stakingType: selectedChainAsset?.stakingType
            )

            self.chainSubscriptionId = nil
        }
    }

    func setupChainRemoteSubscription() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        chainSubscriptionId = stakingRemoteSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil,
            stakingType: selectedChainAsset?.stakingType
        )
    }

    func clearAccountRemoteSubscription() {
        stakingAccountUpdatingService.clearSubscription()
    }

    func setupAccountRemoteSubscription() {
        guard
            let chainAsset = selectedChainAsset,
            let accountId = selectedAccount?.accountId,
            let chainFormat = selectedChainAsset?.chain.chainFormat,
            let stakingType = selectedChainAsset?.stakingType else {
            return
        }

        do {
            try stakingAccountUpdatingService.setupSubscription(
                for: accountId,
                chainAsset: chainAsset,
                chainFormat: chainFormat,
                stakingType: stakingType
            )
        } catch {
            logger?.error("Could setup staking account subscription")
        }
    }

    func provideSelectedAccount() {
        guard let address = selectedAccount?.toAddress() else {
            return
        }

        presenter?.didReceive(selectedAddress: address)
    }

    func provideMaxNominatorsPerValidator(from runtimeService: RuntimeCodingServiceProtocol) {
        guard selectedChainAsset?.stakingType == .relayChain else {
            return
        }

        fetchConstant(
            for: .maxNominatorRewardedPerValidator,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter?.didReceiveMaxNominatorsPerValidator(result: result)
        }
    }

    func provideNewChain() {
        guard let chainAsset = selectedChainAsset else {
            return
        }

        presenter?.didReceive(newChainAsset: chainAsset)
    }

    func provideRewardCalculator(from calculatorService: RewardCalculatorServiceProtocol) {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(calculator: engine)
                } catch {
                    self?.presenter?.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func provideEraStakersInfo(from eraValidatorService: EraValidatorServiceProtocol) {
        let operation = eraValidatorService.fetchInfoOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(eraStakersInfo: info)
                    self?.fetchEraCompletionTime()
                } catch {
                    self?.presenter?.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func provideNetworkStakingInfo() {
        guard let chainId = selectedChainAsset?.chain.chainId, let eraInfoOperationFactory = eraInfoOperationFactory else {
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(networkStakingInfoError: ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let wrapper = eraInfoOperationFactory.networkStakingOperation(
            for: sharedState.eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(networkStakingInfo: info)
                } catch {
                    self?.presenter?.didReceive(networkStakingInfoError: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func fetchEraCompletionTime() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(eraCountdownResult: .failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            presenter?.didReceive(eraCountdownResult: .failure(ChainRegistryError.connectionUnavailable))
            return
        }

        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

        operationWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operationWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.presenter?.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }

//    Parachain

    func handleDelegatorState(
        delegatorState: ParachainStakingDelegatorState?,
        chainAsset _: ChainAsset
    ) {
        if let state = delegatorState {
            fetchCollatorsDelegations(accountIds: state.delegations.map(\.owner))

            let idsOperation: BaseOperation<[AccountId]> = ClosureOperation { state.delegations.map(\.owner) }
            let idsWrapper = CompoundOperationWrapper(targetOperation: idsOperation)

            let collatorInfosOperation = collatorOperationFactory.candidateInfos(for: idsWrapper)
            collatorInfosOperation.targetOperation.completionBlock = { [weak self] in

                DispatchQueue.main.async {
                    do {
                        let collators = try collatorInfosOperation.targetOperation.extractNoCancellableResultData() ?? []

                        self?.collatorIds = collators.map(\.owner)

                        let delegationInfos: [ParachainStakingDelegationInfo] = state.delegations.compactMap { delegation in
                            guard let collator = collators.first(where: { $0.owner == delegation.owner }) else {
                                return nil
                            }
                            return ParachainStakingDelegationInfo(
                                delegation: delegation,
                                collator: collator
                            )
                        }
                        self?.presenter?.didReceive(delegationInfos: delegationInfos)
                    } catch {
                        self?.logger?.error("handleDelegatorState.error: \(error)")
                    }
                }
            }
            operationManager.enqueue(operations: collatorInfosOperation.allOperations, in: .transient)
        } else {
            presenter?.didReceive(delegationInfos: nil)
        }
    }
}
