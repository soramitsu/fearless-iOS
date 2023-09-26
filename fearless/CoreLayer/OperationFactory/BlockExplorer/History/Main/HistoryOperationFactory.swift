import CommonWallet
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class HistoryOperationFactoriesAssembly {
    static func createOperationFactory(
        chainAsset: ChainAsset,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    ) -> HistoryOperationFactoryProtocol? {
        switch chainAsset.chain.externalApi?.history?.type {
        case .subquery:
            return SubqueryHistoryOperationFactory(txStorage: txStorage, chainRegistry: ChainRegistryFacade.sharedRegistry)
        case .subsquid:
            return SubsquidHistoryOperationFactory(txStorage: txStorage)
        case .giantsquid:
            return GiantsquidHistoryOperationFactory(txStorage: txStorage)
        case .sora:
            return SoraHistoryOperationFactory(txStorage: AnyDataProviderRepository(txStorage))
        case .alchemy:
            return AlchemyHistoryOperationFactory(txStorage: txStorage, alchemyService: AlchemyService())
        case .etherscan:
            return EtherscanHistoryOperationFactory()
        case .none:
            return nil
        }
    }
}

protocol HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?>
}
