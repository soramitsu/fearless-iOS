import RobinHood
import CommonWallet

final class WalletTransactionHistoryDependencyContainer {
    struct WalletTransactionHistoryDependencies {
        let dataProvider: SingleValueProvider<AssetTransactionPageData>?
        let historyService: HistoryServiceProtocol
    }

    private let selectedAccount: MetaAccountModel
    var dependencies: WalletTransactionHistoryDependencies?

    init(selectedAccount: MetaAccountModel) {
        self.selectedAccount = selectedAccount
    }

    func createDependencies(for chainAsset: ChainAsset, selectedAccount: MetaAccountModel) {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return
        }

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let operationFactory: HistoryOperationFactoryProtocol
        switch chainAsset.chainAssetType {
        case .soraAsset:
            operationFactory = SoraHistoryOperationFactory(txStorage: AnyDataProviderRepository(txStorage))
        default:
            operationFactory = HistoryOperationFactory(
                txStorage: AnyDataProviderRepository(txStorage),
                runtimeService: runtimeService
            )
        }
        let dataProviderFactory = HistoryDataProviderFactory(
            cacheFacade: SubstrateDataStorageFacade.shared,
            operationFactory: operationFactory
        )

        let service = HistoryService(operationFactory: operationFactory, operationQueue: OperationQueue())
        var dataProvider: SingleValueProvider<AssetTransactionPageData>?
        if let utilityChainAsset = getUtilityAsset(for: chainAsset),
           let address = selectedAccount.fetch(for: utilityChainAsset.chain.accountRequest())?.toAddress() {
            dataProvider = try? dataProviderFactory.createDataProvider(
                for: address,
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                targetIdentifier: "wallet.transaction.history.\(address)",
                using: .main
            )
        }
        dependencies = WalletTransactionHistoryDependencies(dataProvider: dataProvider, historyService: service)
    }

    private func getUtilityAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if chainAsset.chain.isSora, !chainAsset.isUtility,
           let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }
        return chainAsset
    }
}
