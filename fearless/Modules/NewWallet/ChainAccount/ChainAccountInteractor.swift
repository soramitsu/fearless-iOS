import UIKit
import RobinHood
import BigInt
import SSFUtils
import SoraKeystore
import SSFModels

final class ChainAccountInteractor {
    enum Constants {
        static let remoteFetchTimerTimeInterval: TimeInterval = 30
    }

    weak var presenter: ChainAccountInteractorOutputProtocol?
    var chainAsset: ChainAsset
    var availableChainAssets: [ChainAsset] = []

    private var wallet: MetaAccountModel
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let dependencyContainer = BalanceInfoDepencyContainer()
    private var currentDependencies: BalanceInfoDependencies?
    private let ethRemoteBalanceFetching: EthereumRemoteBalanceFetching

    private var remoteFetchTimer: Timer?

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        chainAssetFetching: ChainAssetFetchingProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        ethRemoteBalanceFetching: EthereumRemoteBalanceFetching
    ) {
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.repository = repository
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.chainAssetFetching = chainAssetFetching
        self.storageRequestFactory = storageRequestFactory
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.ethRemoteBalanceFetching = ethRemoteBalanceFetching
    }

    private func getAvailableChainAssets() {
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.assetName(chainAsset.asset.symbol), .ecosystem(chainAsset.defineEcosystem())],
            sortDescriptors: []
        ) { [weak self] result in
            switch result {
            case let .success(availableChainAssets):
                self?.availableChainAssets = availableChainAssets
            default:
                self?.availableChainAssets = []
            }
        }
    }

    private func fetchChainAssetBasedData() {
        guard let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset) else {
            return
        }

        currentDependencies = dependencies

        if let runtimeService = dependencies.runtimeService,
           let connection = dependencies.connection {
            fetchBalanceLocks(
                runtimeService: runtimeService,
                connection: connection
            )
        }

        fetchMinimalBalance(
            using: dependencies.existentialDepositService
        )

        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            dependencies.accountInfoFetching.fetch(for: chainAsset, accountId: accountId) { [weak self] chainAsset, accountInfo in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.presenter?.didReceive(accountInfo: accountInfo, for: chainAsset, accountId: accountId)

                strongSelf.walletBalanceSubscriptionAdapter.subscribeChainAssetBalance(
                    walletId: strongSelf.wallet.metaId,
                    chainAsset: chainAsset,
                    deliverOn: .main,
                    handler: strongSelf
                )
            }
        }
    }

    private func fetchBalanceLocks(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let balanceLocksOperation = createBalanceLocksFetchOperation(
                for: accountId,
                runtimeService: runtimeService,
                connection: connection
            )
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

    private func createBalanceLocksFetchOperation(
        for accountId: AccountId,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<BalanceLocks?> {
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

    private func fetchMinimalBalance(using service: ExistentialDepositServiceProtocol) {
        service.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }
    }
}

extension ChainAccountInteractor: ChainAccountInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        getAvailableChainAssets()
        fetchChainAssetBasedData()
        updateData()
    }

    func getAvailableExportOptions(for address: String) {
        fetchChainAccountFor(
            meta: wallet,
            chain: chainAsset.chain,
            address: address
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
                        for: self.wallet,
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
        if let newChainAsset = availableChainAssets.first(where: { $0.chain.chainId == chain.chainId }) {
            chainAsset = newChainAsset
            presenter?.didUpdate(chainAsset: chainAsset)

            fetchChainAssetBasedData()
        } else {
            assertionFailure("Unable to select this chain")
        }
    }

    func updateData() {
        guard
            remoteFetchTimer == nil,
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            chainAsset.chain.isEthereum
        else {
            return
        }

        remoteFetchTimer = Timer.scheduledTimer(withTimeInterval: Constants.remoteFetchTimerTimeInterval, repeats: false, block: { [weak self] timer in
            timer.invalidate()
            self?.remoteFetchTimer = nil
        })
        ethRemoteBalanceFetching.fetch(for: chainAsset, accountId: accountId, completionBlock: { _, _ in })
    }
}

extension ChainAccountInteractor: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        if let updated = event.updatedChains.first(where: { [weak self] updatedChain in
            guard let self = self else { return false }
            return updatedChain.chainId == self.chainAsset.chain.chainId
        }) {
            chainAsset = ChainAsset(chain: updated, asset: chainAsset.asset)

            fetchChainAssetBasedData()
        }
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account
        fetchChainAssetBasedData()
        presenter?.didReceiveWallet(wallet: event.account)
    }
}

extension ChainAccountInteractor: AccountFetching {}

extension ChainAccountInteractor: WalletBalanceSubscriptionHandler {
    func handle(result: WalletBalancesResult) {
        presenter?.didReceiveWalletBalancesResult(result)
    }
}
