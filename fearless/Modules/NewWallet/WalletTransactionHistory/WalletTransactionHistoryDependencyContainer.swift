import RobinHood
import CommonWallet
import SSFModels

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
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        guard
            let operationFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
                chainAsset: chainAsset,
                txStorage: AnyDataProviderRepository(txStorage)
            )
        else {
            return
        }

        let dataProviderFactory = HistoryDataProviderFactory(
            cacheFacade: SubstrateDataStorageFacade.shared,
            operationFactory: operationFactory
        )

        let service = HistoryService(operationFactory: operationFactory, operationQueue: OperationQueue())
        var dataProvider: SingleValueProvider<AssetTransactionPageData>?
        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            dataProvider = try? dataProviderFactory.createDataProvider(
                for: address,
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                targetIdentifier: "wallet.transaction.history.\(address).\(chainAsset.chainAssetId)",
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
