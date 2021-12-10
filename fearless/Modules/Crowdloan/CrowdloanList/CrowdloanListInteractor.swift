import UIKit
import RobinHood

final class CrowdloanListInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanListInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol
    let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let settings: CrowdloanChainSettings
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    private var blockNumberSubscriptionId: UUID?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var crowdloansRequest: CompoundOperationWrapper<[Crowdloan]>?
    private var displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>?

    deinit {
        if let subscriptionId = blockNumberSubscriptionId, let chain = settings.value {
            blockNumberSubscriptionId = nil
            crowdloanRemoteSubscriptionService.detach(for: subscriptionId, chainId: chain.chainId)
        }
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        settings: CrowdloanChainSettings,
        chainRegistry: ChainRegistryProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.chainRegistry = chainRegistry
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.crowdloanLocalSubscriptionFactory = crowdloanLocalSubscriptionFactory
        self.crowdloanRemoteSubscriptionService = crowdloanRemoteSubscriptionService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
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

    private func notifyCrowdolansFetchWithError(error: Error) {
        presenter.didReceiveCrowdloans(result: .failure(error))
        presenter.didReceiveContributions(result: .failure(error))
        presenter.didReceiveLeaseInfo(result: .failure(error))
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

    private func subscribeToAccountInfo(for accountId: AccountId, chain: ChainModel) {
        accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
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
}

extension CrowdloanListInteractor {
    func setup(with accountId: AccountId, chain: ChainModel) {
        presenter.didReceiveSelectedChain(result: .success(chain))

        subscribeToAccountInfo(for: accountId, chain: chain)

        provideCrowdloans(for: chain)

        subscribeToDisplayInfo(for: chain)

        provideConstants(for: chain)
    }

    func refresh(with chain: ChainModel) {
        displayInfoProvider?.refresh()

        provideCrowdloans(for: chain)

        provideConstants(for: chain)
    }

    func clear() {
        if let oldChain = settings.value {
            putOffline(with: oldChain)
        }

        clear(singleValueProvider: &displayInfoProvider)
        clear(dataProvider: &accountInfoProvider)

        crowdloansRequest?.cancel()
        crowdloansRequest = nil
    }

    func handleSelectionChange(to chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            presenter.didReceiveAccountInfo(
                result: .failure(ChainAccountFetchingError.accountNotExists)
            )
            return
        }

        setup(with: accountId, chain: chain)
        becomeOnline(with: chain)
    }

    func becomeOnline(with chain: ChainModel) {
        if blockNumberSubscriptionId == nil {
            blockNumberSubscriptionId = crowdloanRemoteSubscriptionService.attach(for: chain.chainId)
        }

        if blockNumberProvider == nil {
            blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
        }
    }

    func putOffline(with chain: ChainModel) {
        if let subscriptionId = blockNumberSubscriptionId {
            blockNumberSubscriptionId = nil
            crowdloanRemoteSubscriptionService.detach(for: subscriptionId, chainId: chain.chainId)
        }

        clear(dataProvider: &blockNumberProvider)
    }

    func provideCrowdloans(for chain: ChainModel) {
        guard crowdloansRequest == nil else {
            return
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            notifyCrowdolansFetchWithError(error: ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            notifyCrowdolansFetchWithError(error: ChainRegistryError.runtimeMetadaUnavailable)
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
                        self?.notifyCrowdolansFetchWithError(error: error)
                    }
                }
            }
        }

        operationManager.enqueue(operations: crowdloanWrapper.allOperations, in: .transient)
    }
}
