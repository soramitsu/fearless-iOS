import Foundation
import RobinHood
import SSFUtils
import SSFModels

protocol StakingBalanceRelaychainStrategyOutput: AnyObject {
    func didReceive(ledgerResult: Result<StakingLedger?, Error>)
    func didReceive(activeEraResult: Result<EraIndex?, Error>)
    func didReceive(stashItemResult: Result<StashItem?, Error>)
    func didReceive(controllerResult: Result<ChainAccountResponse?, Error>)
    func didReceive(stashResult: Result<ChainAccountResponse?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
}

final class StakingBalanceRelaychainStrategy: AccountFetching {
    weak var output: StakingBalanceRelaychainStrategyOutput?
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let runtimeCodingService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private let connection: JSONRPCEngine
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel

    init(
        output: StakingBalanceRelaychainStrategyOutput?,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        connection: JSONRPCEngine,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.output = output
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.runtimeCodingService = runtimeCodingService
        self.operationManager = operationManager
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.connection = connection
        self.accountRepository = accountRepository
        self.chainAsset = chainAsset
        self.wallet = wallet
    }

    func fetchAccounts(for stashItem: StashItem) {
        fetchChainAccount(
            chain: chainAsset.chain,
            address: stashItem.controller,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.output?.didReceive(controllerResult: result)
        }

        fetchChainAccount(
            chain: chainAsset.chain,
            address:
            stashItem.stash,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.output?.didReceive(stashResult: result)
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
                    self?.output?.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.output?.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}

extension StakingBalanceRelaychainStrategy: StakingBalanceStrategy {
    func setup() {
        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashControllerProvider = subscribeStashItemProvider(for: address)
        }

        fetchEraCompletionTime()
    }
}

extension StakingBalanceRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceive(ledgerResult: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(activeEraInfo):
            fetchEraCompletionTime()
            output?.didReceive(activeEraResult: .success(activeEraInfo?.index))
        case let .failure(error):
            output?.didReceive(activeEraResult: .failure(error))
        }
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let stashItem = try result.get()

            if let stashItem = stashItem {
                if let accountId = try? AddressFactory.accountId(
                    from: stashItem.controller,
                    chain: chainAsset.chain
                ) {
                    ledgerProvider = subscribeLedgerInfo(for: accountId, chainAsset: chainAsset)
                }

                fetchAccounts(for: stashItem)
            }

            output?.didReceive(stashItemResult: .success(stashItem))
        } catch {
            output?.didReceive(stashResult: .failure(error))
        }
    }
}
