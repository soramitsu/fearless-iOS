import UIKit
import FearlessUtils
import RobinHood

final class CrowdloanListInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanListInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let localSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    let crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol
    let settings: CrowdloanChainSettings
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    private var remoteSubscriptionId: UUID?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var crowdloansRequest: CompoundOperationWrapper<[Crowdloan]>?
    private var displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>?

    deinit {
        clear()
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        settings: CrowdloanChainSettings,
        chainRegistry: ChainRegistryProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        localSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.chainRegistry = chainRegistry
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.localSubscriptionFactory = localSubscriptionFactory
        self.crowdloanRemoteSubscriptionService = crowdloanRemoteSubscriptionService
        self.settings = settings
        self.operationManager = operationManager
        self.logger = logger
    }

    private func provideContributions(
        for crowdloans: [Crowdloan],
        chain: ChainModel,
        connection: ChainConnection,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        guard !crowdloans.isEmpty else {
            presenter.didReceiveContributions(result: .success([:]))
            return
        }

        guard let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest()) else {
            presenter.didReceiveContributions(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let contributionsOperation: BaseOperation<[CrowdloanContributionResponse]> =
            OperationCombiningService(operationManager: operationManager) { [weak self] in
                guard let strongSelf = self else {
                    return []
                }

                return crowdloans.map { crowdloan in
                    strongSelf.crowdloanOperationFactory.fetchContributionOperation(
                        connection: connection,
                        runtimeService: runtimeService,
                        accountId: accountResponse.accountId,
                        trieIndex: crowdloan.fundInfo.trieIndex
                    )
                }
            }.longrunOperation()

        contributionsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let contributions = try contributionsOperation.extractNoCancellableResultData().toDict()
                    self?.presenter.didReceiveContributions(result: .success(contributions))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveContributions(result: .success([:]))
                    } else {
                        self?.presenter.didReceiveContributions(result: .failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [contributionsOperation], in: .transient)
    }

    private func provideLeaseInfo(
        for crowdloans: [Crowdloan],
        connection: ChainConnection,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        guard !crowdloans.isEmpty else {
            presenter.didReceiveLeaseInfo(result: .success([:]))
            return
        }

        let paraIds = crowdloans.map(\.paraId)

        let queryWrapper = crowdloanOperationFactory.fetchLeaseInfoOperation(
            connection: connection,
            runtimeService: runtimeService,
            paraIds: paraIds
        )

        queryWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let leaseInfo = try queryWrapper.targetOperation.extractNoCancellableResultData().toMap()
                    self?.presenter.didReceiveLeaseInfo(result: .success(leaseInfo))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveLeaseInfo(result: .success([:]))
                    } else {
                        self?.presenter.didReceiveLeaseInfo(result: .failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: queryWrapper.allOperations, in: .transient)
    }

    private func notifyCrowdloansFetchSame(error: Error) {
        presenter.didReceiveCrowdloans(result: .failure(error))
        presenter.didReceiveContributions(result: .failure(error))
        presenter.didReceiveLeaseInfo(result: .failure(error))
    }

    private func provideCrowdloans(for chain: ChainModel) {
        guard crowdloansRequest == nil else {
            return
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            notifyCrowdloansFetchSame(error: ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            notifyCrowdloansFetchSame(error: ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let crowdloanWrapper = crowdloanOperationFactory.fetchCrowdloansOperation(
            connection: connection,
            runtimeService: runtimeService
        )

        crowdloansRequest = crowdloanWrapper

        crowdloanWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.crowdloansRequest = nil

                do {
                    let crowdloans = try crowdloanWrapper.targetOperation.extractNoCancellableResultData()
                    self?.provideContributions(
                        for: crowdloans,
                        chain: chain,
                        connection: connection,
                        runtimeService: runtimeService
                    )
                    self?.provideLeaseInfo(
                        for: crowdloans,
                        connection: connection,
                        runtimeService: runtimeService
                    )
                    self?.presenter.didReceiveCrowdloans(result: .success(crowdloans))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveCrowdloans(result: .success([]))
                        self?.presenter.didReceiveContributions(result: .success([:]))
                        self?.presenter.didReceiveLeaseInfo(result: .success([:]))
                    } else {
                        self?.notifyCrowdloansFetchSame(error: error)
                    }
                }
            }
        }

        operationManager.enqueue(operations: crowdloanWrapper.allOperations, in: .transient)
    }

    private func subscribeToDisplayInfo(for chain: ChainModel) {
        displayInfoProvider = nil

        guard let crowdloanUrl = chain.externalApi?.crowdloans?.url else {
            presenter.didReceiveDisplayInfo(result: .success([:]))
            return
        }

        displayInfoProvider = jsonDataProviderFactory.getJson(for: crowdloanUrl)

        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter.didReceiveDisplayInfo(result: .success(result.toMap()))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveDisplayInfo(result: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        displayInfoProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func provideConstants(for chain: ChainModel) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            presenter.didReceiveBlockDuration(result: .failure(error))
            presenter.didReceiveLeasingPeriod(result: .failure(error))
            return
        }

        fetchConstant(
            for: .babeBlockTime,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            self?.presenter.didReceiveBlockDuration(result: result)
        }

        fetchConstant(
            for: .paraLeasingPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingPeriod, Error>) in
            self?.presenter.didReceiveLeasingPeriod(result: result)
        }
    }

    private func clear() {
        if let oldChain = settings.value {
            putOffline(with: oldChain)
        }

        displayInfoProvider = nil

        crowdloansRequest?.cancel()
        crowdloansRequest = nil
    }
}

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    func setup() {
        guard let chain = settings.value else {
            presenter.didReceiveSelectedChain(result: .failure(
                PersistentValueSettingsError.missingValue
            ))
            return
        }

        setup(with: chain)
    }

    private func setup(with chain: ChainModel) {
        presenter.didReceiveSelectedChain(result: .success(chain))

        provideCrowdloans(for: chain)

        subscribeToDisplayInfo(for: chain)

        provideConstants(for: chain)
    }

    func refresh() {
        guard let chain = settings.value else {
            presenter.didReceiveSelectedChain(result: .failure(
                PersistentValueSettingsError.missingValue
            ))
            return
        }

        refresh(with: chain)
    }

    func refresh(with chain: ChainModel) {
        displayInfoProvider?.refresh()

        provideCrowdloans(for: chain)

        provideConstants(for: chain)
    }

    func saveSelected(chainModel: ChainModel) {
        if settings.value?.chainId != chainModel.chainId {
            clear()

            settings.save(value: chainModel, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case .success:
                    self?.setup(with: chainModel)
                    self?.becomeOnline(with: chainModel)
                case let .failure(error):
                    self?.presenter.didReceiveSelectedChain(result: .failure(error))
                }
            }
        }
    }

    func becomeOnline() {
        guard let chain = settings.value else {
            return
        }

        becomeOnline(with: chain)
    }

    private func becomeOnline(with chain: ChainModel) {
        if remoteSubscriptionId == nil {
            remoteSubscriptionId = crowdloanRemoteSubscriptionService.attach(for: chain.chainId)
        }

        if blockNumberProvider == nil {
            blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
        }
    }

    func putOffline() {
        guard let chain = settings.value else {
            return
        }

        putOffline(with: chain)
    }

    private func putOffline(with chain: ChainModel) {
        if let subscriptionId = remoteSubscriptionId {
            remoteSubscriptionId = nil
            crowdloanRemoteSubscriptionService.detach(for: subscriptionId, chainId: chain.chainId)
        }

        clear(dataProvider: &blockNumberProvider)
    }
}

extension CrowdloanListInteractor: CrowdloanLocalStorageSubscriber, CrowdloanLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    var subscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol { localSubscriptionFactory }

    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId: ChainModel.Id) {
        if let chain = settings.value, chain.chainId == chainId {
            provideCrowdloans(for: chain)
            presenter.didReceiveBlockNumber(result: result)
        }
    }
}
