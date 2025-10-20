import RobinHood

import SSFModels
import SoraFoundation

enum WalletTransactionHistoryDependencyContainerError: Error {
    case unsupported
}

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

    func createDependencies(for chainAsset: ChainAsset, selectedAccount: MetaAccountModel) throws {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        guard
            let operationFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
                chain: chainAsset.chain,
                txStorage: AnyDataProviderRepository(txStorage)
            )
        else {
            throw WalletTransactionHistoryDependencyContainerError.unsupported
        }

        let dataProviderFactory = HistoryDataProviderFactory(
            operationFactory: operationFactory
        )

        let service = HistoryService(operationFactory: operationFactory, operationQueue: OperationQueue())
        var dataProvider: SingleValueProvider<AssetTransactionPageData>?
        let filters = transactionHistoryFilters(for: chainAsset.chain).compactMap {
            $0.items as? [WalletTransactionHistoryFilter]
        }.reduce([], +)

        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            dataProvider = try? dataProviderFactory.createDataProvider(
                for: address,
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                targetIdentifier: "wallet.transaction.history.\(address).\(chainAsset.chainAssetId)",
                filters: filters
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

    func transactionHistoryFilters(for chain: ChainModel) -> [FilterSet] {
        var filters: [WalletTransactionHistoryFilter] = [
            WalletTransactionHistoryFilter(type: .transfer, selected: true)
        ]
        if chain.externalApi?.history?.type != .giantsquid && !chain.isReef {
            filters.insert(WalletTransactionHistoryFilter(type: .other, selected: true), at: 1)
        }
        if chain.hasStakingRewardHistory || chain.isSora {
            filters.insert(WalletTransactionHistoryFilter(type: .reward, selected: true), at: 1)
        }
        if chain.hasPolkaswap {
            filters.insert(WalletTransactionHistoryFilter(type: .swap, selected: true), at: 0)
            filters.removeAll(where: { $0.type == .other })
        }

        return [FilterSet(
            title: R.string.localizable.commonShow(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
            ),
            items: filters
        )]
    }
}
