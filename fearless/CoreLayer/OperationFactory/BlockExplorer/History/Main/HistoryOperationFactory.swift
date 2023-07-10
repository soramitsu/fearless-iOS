import CommonWallet
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class HistoryOperationFactoriesAssembly {
    static func createOperationFactory(
        chainAsset: ChainAsset,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        runtimeService: RuntimeCodingServiceProtocol?
    ) -> HistoryOperationFactoryProtocol? {
        switch chainAsset.chain.externalApi?.history?.type {
        case .subquery:
            guard let runtimeService = runtimeService else {
                return nil
            }

            return SubqueryHistoryOperationFactory(txStorage: txStorage, runtimeService: runtimeService)
        case .subsquid:
            return SubsquidHistoryOperationFactory(txStorage: txStorage)
        case .giantsquid:
            return GiantsquidHistoryOperationFactory(txStorage: txStorage)
        case .sora:
            return SoraHistoryOperationFactory(txStorage: AnyDataProviderRepository(txStorage))
        case .none:
            return GiantsquidHistoryOperationFactory(txStorage: txStorage)
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
