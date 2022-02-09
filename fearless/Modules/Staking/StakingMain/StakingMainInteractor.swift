import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils
import SoraFoundation

final class StakingMainInteractor: RuntimeConstantFetching {
    weak var presenter: StakingMainInteractorOutputProtocol!

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol {
        sharedState.stakingLocalSubscriptionFactory
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
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingServiceFactory: StakingServiceFactoryProtocol
    let accountProviderFactory: AccountProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    let commonSettings: SettingsManagerProtocol
    let logger: LoggerProtocol?

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

    init(
        selectedWalletSettings: SelectedWalletSettings,
        sharedState: StakingSharedState,
        chainRegistry: ChainRegistryProtocol,
        stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingServiceFactory: StakingServiceFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationManager: OperationManagerProtocol,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        commonSettings: SettingsManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.sharedState = sharedState
        self.chainRegistry = chainRegistry
        self.stakingRemoteSubscriptionService = stakingRemoteSubscriptionService
        self.stakingAccountUpdatingService = stakingAccountUpdatingService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingServiceFactory = stakingServiceFactory
        self.accountProviderFactory = accountProviderFactory
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.applicationHandler = applicationHandler
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.commonSettings = commonSettings
        self.logger = logger
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
        guard let chainAsset = selectedChainAsset else {
            return
        }

        do {
            let eraValidatorService = try stakingServiceFactory.createEraValidatorService(
                for: chainAsset.chain.chainId
            )

            let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
                for: chainAsset.chain.chainId,
                assetPrecision: Int16(chainAsset.asset.precision),
                validatorService: eraValidatorService
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
                closure: nil
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
            closure: nil
        )
    }

    func clearAccountRemoteSubscription() {
        stakingAccountUpdatingService.clearSubscription()
    }

    func setupAccountRemoteSubscription() {
        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let accountId = selectedAccount?.accountId,
            let chainFormat = selectedChainAsset?.chain.chainFormat else {
            return
        }

        do {
            try stakingAccountUpdatingService.setupSubscription(
                for: accountId,
                chainId: chainId,
                chainFormat: chainFormat
            )
        } catch {
            logger?.error("Could setup staking account subscription")
        }
    }

    func provideSelectedAccount() {
        guard let address = selectedAccount?.toAddress() else {
            return
        }

        presenter.didReceive(selectedAddress: address)
    }

    func provideMaxNominatorsPerValidator(from runtimeService: RuntimeCodingServiceProtocol) {
        fetchConstant(
            for: .maxNominatorRewardedPerValidator,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveMaxNominatorsPerValidator(result: result)
        }
    }

    func provideNewChain() {
        guard let chainAsset = selectedChainAsset else {
            return
        }

        presenter.didReceive(newChainAsset: chainAsset)
    }

    func provideRewardCalculator(from calculatorService: RewardCalculatorServiceProtocol) {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(calculator: engine)
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func provideEraStakersInfo(from eraValidatorService: EraValidatorServiceProtocol) {
        let operation = eraValidatorService.fetchInfoOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(eraStakersInfo: info)
                    self?.fetchEraCompletionTime()
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func provideNetworkStakingInfo() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter.didReceive(networkStakingInfoError: ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let wrapper = eraInfoOperationFactory.networkStakingOperation(
            for: sharedState.eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(networkStakingInfo: info)
                } catch {
                    self?.presenter.didReceive(networkStakingInfoError: error)
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
            presenter.didReceive(eraCountdownResult: .failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            presenter.didReceive(eraCountdownResult: .failure(ChainRegistryError.connectionUnavailable))
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
                    self?.presenter.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.presenter.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}
