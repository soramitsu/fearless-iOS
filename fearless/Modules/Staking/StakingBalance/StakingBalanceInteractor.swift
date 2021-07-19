import RobinHood
import IrohaCrypto

final class StakingBalanceInteractor: AccountFetching {
    weak var presenter: StakingBalanceInteractorOutputProtocol!

    let chain: Chain
    let accountAddress: AccountAddress
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageRequestFactory: LocalStorageRequestFactoryProtocol
    let operationManager: OperationManagerProtocol
    let priceProvider: AnySingleValueProvider<PriceData>
    let providerFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let eraCountdownService: EraCountdownServiceProtocol
    var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    var stashControllerProvider: StreamableProvider<StashItem>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

    init(
        chain: Chain,
        accountAddress: AccountAddress,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        localStorageRequestFactory: LocalStorageRequestFactoryProtocol,
        priceProvider: AnySingleValueProvider<PriceData>,
        providerFactory: SingleValueProviderFactoryProtocol,
        eraCountdownService: EraCountdownServiceProtocol,
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
        self.eraCountdownService = eraCountdownService
        self.substrateProviderFactory = substrateProviderFactory
        self.operationManager = operationManager
    }

    func fetchAccounts(for stashItem: StashItem) {
        fetchAccount(
            for: stashItem.controller,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceive(controllerResult: result)
        }

        fetchAccount(
            for: stashItem.stash,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceive(stashResult: result)
        }
    }

    func fetchEraTime() {
        let operation = eraCountdownService.fetchCountdownOperationWrapper()
        operation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(eraCompletionTimeResult: .success(result))
                } catch {
                    self?.presenter.didReceive(eraCompletionTimeResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }
}

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subsribeToActiveEra()
        subscribeToStashControllerProvider()
        fetchEraTime()
    }
}
