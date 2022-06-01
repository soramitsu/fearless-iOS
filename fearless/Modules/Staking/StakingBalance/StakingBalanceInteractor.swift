import RobinHood
import IrohaCrypto
import FearlessUtils

final class StakingBalanceInteractor: AccountFetching {
    weak var presenter: StakingBalanceInteractorOutputProtocol!

    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let chainAsset: ChainAsset
    let selectedAccount: MetaAccountModel
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    var priceProvider: AnySingleValueProvider<PriceData>?
    let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    var stashControllerProvider: StreamableProvider<StashItem>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    let connection: JSONRPCEngine
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>

    init(
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        connection: JSONRPCEngine,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.runtimeCodingService = runtimeCodingService
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.operationManager = operationManager
        self.connection = connection
        self.accountRepository = accountRepository
    }

    func fetchAccounts(for stashItem: StashItem) {
        fetchChainAccount(
            chain: chainAsset.chain,
            address: stashItem.controller,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceive(controllerResult: result)
        }

        fetchChainAccount(
            chain: chainAsset.chain,
            address:
            stashItem.stash,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceive(stashResult: result)
        }
    }

    func fetchEraCompletionTime() {
        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeCodingService
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

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashControllerProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        fetchEraCompletionTime()
    }
}

extension StakingBalanceInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceive(priceResult: result)
    }
}

extension StakingBalanceInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceive(ledgerResult: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(activeEraInfo):
            fetchEraCompletionTime()
            presenter.didReceive(activeEraResult: .success(activeEraInfo?.index))
        case let .failure(error):
            presenter.didReceive(activeEraResult: .failure(error))
        }
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let stashItem = try result.get()

            if let stashItem = stashItem {
                let addressFactory = SS58AddressFactory()
                if let accountId = try? addressFactory.accountId(
                    fromAddress: stashItem.controller,
                    type: chainAsset.chain.addressPrefix
                ) {
                    ledgerProvider = subscribeLedgerInfo(for: accountId, chainAsset: chainAsset)
                }

                fetchAccounts(for: stashItem)
            }

            presenter?.didReceive(stashItemResult: .success(stashItem))
        } catch {
            presenter.didReceive(stashResult: .failure(error))
        }
    }
}
