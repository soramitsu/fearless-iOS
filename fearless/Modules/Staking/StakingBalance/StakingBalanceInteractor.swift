import RobinHood
import IrohaCrypto

final class StakingBalanceInteractor {
    weak var presenter: StakingBalanceInteractorOutputProtocol!

    private let chain: Chain
    private let accountAddress: AccountAddress
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let runtimeCodingService: RuntimeCodingServiceProtocol
    private let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    private let localStorageRequestFactory: LocalStorageRequestFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let priceProvider: AnySingleValueProvider<PriceData>
    private let providerFactory: SingleValueProviderFactoryProtocol
    private let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

    init(
        chain: Chain,
        accountAddress: AccountAddress,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        localStorageRequestFactory: LocalStorageRequestFactoryProtocol,
        priceProvider: AnySingleValueProvider<PriceData>,
        providerFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.chain = chain
        self.accountAddress = accountAddress
        self.accountRepository = accountRepository
        self.runtimeCodingService = runtimeCodingService
        self.chainStorage = chainStorage
        self.localStorageRequestFactory = localStorageRequestFactory
        self.priceProvider = priceProvider
        self.providerFactory = providerFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.operationManager = operationManager
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(priceResult: .success(nil))
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(priceResult: .success(item))
                    case .delete:
                        self?.presenter.didReceive(priceResult: .success(nil))
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(priceResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subscribeToElectionStatus() {
        guard electionStatusProvider == nil else {
            return
        }

        guard let electionStatusProvider = try? providerFactory
            .getElectionStatusProvider(chain: chain, runtimeService: runtimeCodingService)
        else {
            return
        }

        self.electionStatusProvider = electionStatusProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedElectionStatus>]) in
            if let electionStatus = changes.reduceToLastChange() {
                self?.presenter.didReceive(electionStatusResult: .success(electionStatus.item))
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(electionStatusResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        electionStatusProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subsribeToActiveEra() {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .activeEra)
            )
        activeEraWrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let activeEra = try activeEraWrapper
                        .targetOperation.extractNoCancellableResultData()?.index
                    self.presenter.didReceive(activeEraResult: .success(activeEra))
                } catch {
                    self.presenter.didReceive(activeEraResult: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: activeEraWrapper.allOperations + [codingFactoryOperation], in: .transient)
    }

    private func subscribeToStashControllerProvider() {
        guard stashControllerProvider == nil else {
            return
        }

        let provider = substrateProviderFactory.createStashItemProvider(for: accountAddress)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.handle(stashItem: stashItem)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceive(stashItemResult: .failure(error))
            return
        }

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )

        stashControllerProvider = provider
    }

    private func handle(stashItem: StashItem?) {
        if let stashItem = stashItem {
            subscribeToLedger(address: stashItem.controller)
            fetchController(for: stashItem.controller)
        }

        presenter?.didReceive(stashItemResult: .success(stashItem))
    }

    private func subscribeToLedger(address: String) {
        guard ledgerProvider == nil else {
            return
        }

        guard let ledgerProvider = try? providerFactory
            .getLedgerInfoProvider(for: address, runtimeService: runtimeCodingService)
        else {
            return
        }

        self.ledgerProvider = ledgerProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedLedgerInfo>]) in
            if let ledgerInfo = changes.reduceToLastChange() {
                self?.presenter.didReceive(ledgerResult: .success(ledgerInfo.item))
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(ledgerResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        ledgerProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func fetchController(for address: AccountAddress) {
        let operation = accountRepository.fetchOperation(by: address, options: RepositoryFetchOptions())

        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let accountItem = try operation.extractNoCancellableResultData()
                    self.presenter.didReceive(fetchControllerResult: .success((accountItem, address)))
                } catch {
                    self.presenter.didReceive(fetchControllerResult: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subscribeToElectionStatus()
        subsribeToActiveEra()
        subscribeToStashControllerProvider()
    }
}
