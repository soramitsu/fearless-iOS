import UIKit
import FearlessUtils
import RobinHood

final class CrowdloanListInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanListInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>
    let subscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    let crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol
    let settings: CrowdloanChainSettings
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var crowdloansRequest: CompoundOperationWrapper<[Crowdloan]>?

    init(
        selectedMetaAccount: MetaAccountModel,
        settings: CrowdloanChainSettings,
        chainRegistry: ChainRegistryProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        localSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol,
        displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.chainRegistry = chainRegistry
        self.displayInfoProvider = displayInfoProvider
        subscriptionFactory = localSubscriptionFactory
        self.crowdloanRemoteSubscriptionService = crowdloanRemoteSubscriptionService
        self.settings = settings
        self.operationManager = operationManager
        self.logger = logger
    }

    private func provideContributions(for crowdloans: [Crowdloan]) {
        guard !crowdloans.isEmpty else {
            presenter.didReceiveContributions(result: .success([:]))
            return
        }

        let chain: ChainModel = settings.value

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            presenter.didReceiveContributions(result: .failure(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            presenter.didReceiveContributions(result: .failure(ChainRegistryError.runtimeMetadaUnavailable))
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

    private func provideLeaseInfo(for crowdloans: [Crowdloan]) {
        guard !crowdloans.isEmpty else {
            presenter.didReceiveLeaseInfo(result: .success([:]))
            return
        }

        let chainId = settings.value.chainId

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            presenter.didReceiveLeaseInfo(result: .failure(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter.didReceiveLeaseInfo(result: .failure(ChainRegistryError.runtimeMetadaUnavailable))
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

    private func provideCrowdloans() {
        guard crowdloansRequest == nil else {
            return
        }

        let chainId = settings.value.chainId

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            let error = ChainRegistryError.connectionUnavailable
            presenter.didReceiveCrowdloans(result: .failure(error))
            presenter.didReceiveContributions(result: .failure(error))
            presenter.didReceiveLeaseInfo(result: .failure(error))
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            presenter.didReceiveCrowdloans(result: .failure(error))
            presenter.didReceiveContributions(result: .failure(error))
            presenter.didReceiveLeaseInfo(result: .failure(error))
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
                    self?.provideContributions(for: crowdloans)
                    self?.provideLeaseInfo(for: crowdloans)
                    self?.presenter.didReceiveCrowdloans(result: .success(crowdloans))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveCrowdloans(result: .success([]))
                        self?.presenter.didReceiveContributions(result: .success([:]))
                        self?.presenter.didReceiveLeaseInfo(result: .success([:]))
                    } else {
                        self?.presenter.didReceiveCrowdloans(result: .failure(error))
                        self?.presenter.didReceiveContributions(result: .failure(error))
                        self?.presenter.didReceiveLeaseInfo(result: .failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: crowdloanWrapper.allOperations, in: .transient)
    }

    private func subscribeToDisplayInfo() {
        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter.didReceiveDisplayInfo(result: .success(result.toMap()))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveDisplayInfo(result: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        displayInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func provideConstants() {
        let chainId = settings.value.chainId

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
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

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    func setup() {
        provideCrowdloans()

        subscribeToDisplayInfo()

        provideConstants()
    }

    func refresh() {
        displayInfoProvider.refresh()

        provideCrowdloans()

        provideConstants()
    }

    func becomeOnline() {
        guard blockNumberProvider == nil else {
            return
        }

        blockNumberProvider = subscribeToBlockNumber(for: settings.value.chainId)
    }

    func putOffline() {
        clear(dataProvider: &blockNumberProvider)
    }
}

extension CrowdloanListInteractor: CrowdloanLocalStorageSubscriber, CrowdloanLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        provideCrowdloans()
        presenter.didReceiveBlockNumber(result: result)
    }
}
