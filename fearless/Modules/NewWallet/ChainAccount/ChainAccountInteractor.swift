import UIKit
import RobinHood
import BigInt
import FearlessUtils
import SoraKeystore

final class ChainAccountInteractor {
    weak var presenter: ChainAccountInteractorOutputProtocol?
    var chainAsset: ChainAsset

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private var selectedMetaAccount: MetaAccountModel
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let connection: JSONRPCEngine
    private let eventCenter: EventCenterProtocol
    private let transactionSubscription: StorageSubscriptionContainer?
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    private let settingsManager: SettingsManager
    private let existentialDepositService: ExistentialDepositServiceProtocol
    private let operationQueue: OperationQueue
    let availableChainAssets: [ChainAsset]

    var accountInfoProvider: AnyDataProviderRepository<DecodedAccountInfo>?

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        eventCenter: EventCenterProtocol,
        transactionSubscription: StorageSubscriptionContainer?,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        settingsManager: SettingsManager,
        existentialDepositService: ExistentialDepositServiceProtocol,
        operationQueue: OperationQueue,
        availableChainAssets: [ChainAsset]
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.connection = connection
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.transactionSubscription = transactionSubscription
        self.repository = repository
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.settingsManager = settingsManager
        self.existentialDepositService = existentialDepositService
        self.operationQueue = operationQueue
        self.availableChainAssets = availableChainAssets
    }

    private func subscribeToAccountInfo() {
        if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        } else {
            presenter?.didReceiveAccountInfo(
                result: .failure(ChainAccountFetchingError.accountNotExists),
                for: chainAsset.chain.chainId
            )
        }
    }

    private func fetchBalanceLocks() {
        if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let balanceLocksOperation = createBalanceLocksFetchOperation(accountId)
            balanceLocksOperation.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let balanceLocks = try balanceLocksOperation.targetOperation.extractNoCancellableResultData()
                        self?.presenter?.didReceiveBalanceLocks(result: .success(balanceLocks))
                    } catch {
                        self?.presenter?.didReceiveBalanceLocks(result: .failure(error))
                    }
                }
            }
            operationManager.enqueue(
                operations: balanceLocksOperation.allOperations,
                in: .transient
            )
        }
    }

    private func createBalanceLocksFetchOperation(_ accountId: AccountId) -> CompoundOperationWrapper<BalanceLocks?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<BalanceLocks>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .balanceLocks
        )

        let mapOperation = ClosureOperation<BalanceLocks?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func provideSelectedCurrency() {
        presenter?.didReceive(currency: selectedMetaAccount.selectedCurrency)
    }
}

extension ChainAccountInteractor: ChainAccountInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)

        subscribeToAccountInfo()
        fetchMinimalBalance()
        fetchBalanceLocks()
        provideSelectedCurrency()

        if let priceId = chainAsset.asset.priceId {
            _ = subscribeToPrice(for: priceId)
        }
    }

    func getAvailableExportOptions(for address: String) {
        fetchChainAccount(
            chain: chainAsset.chain,
            address: address,
            from: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(chainResponse):
                guard let self = self, let response = chainResponse else {
                    self?.presenter?.didReceiveExportOptions(options: [.keystore])
                    return
                }
                let accountId = response.isChainAccount ? response.accountId : nil
                let options = self.availableExportOptionsProvider
                    .getAvailableExportOptions(
                        for: self.selectedMetaAccount,
                        accountId: accountId,
                        isEthereum: response.isEthereumBased
                    )
                self.presenter?.didReceiveExportOptions(options: options)
            default:
                self?.presenter?.didReceiveExportOptions(options: [.keystore])
            }
        }
    }

    func update(chain: ChainModel) {
        if let newChainAsset = availableChainAssets.first(where: { $0.chain == chain }) {
            chainAsset = newChainAsset
            presenter?.didUpdate(chainAsset: chainAsset)
        } else {
            assertionFailure("Unable chain selected")
        }
    }
}

extension ChainAccountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result, for: priceId)
    }
}

extension ChainAccountInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset.chain.chainId)
    }
}

extension ChainAccountInteractor: RuntimeConstantFetching {
    func fetchMinimalBalance() {
        existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }
    }
}

extension ChainAccountInteractor: AnyProviderAutoCleaning {}

extension ChainAccountInteractor: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        if let updated = event.updatedChains.first(where: { [weak self] updatedChain in
            guard let self = self else { return false }
            return updatedChain.chainId == self.chainAsset.chain.chainId
        }) {
            chainAsset = ChainAsset(chain: updated, asset: chainAsset.asset)
        }
    }

    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {
        accountInfoSubscriptionAdapter.reset()
        subscribeToAccountInfo()
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        presenter?.didReceive(currency: event.account.selectedCurrency)
    }
}

extension ChainAccountInteractor: AccountFetching {}
