import CommonWallet
import RobinHood
import IrohaCrypto
import FearlessUtils

final class HistoryOperationFactoriesAssembly {
    static func createOperationFactory(
        chainAsset: ChainAsset,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> HistoryOperationFactoryProtocol {
        switch chainAsset.chain.externalApi?.history?.type {
        case .subquery:
            return SubqueryHistoryOperationFactory(txStorage: txStorage, runtimeService: runtimeService)
        case .subsquid:
            return SubsquidHistoryOperationFactory(txStorage: txStorage, runtimeService: runtimeService)
        case .giantsquid:
            return GiantsquidHistoryOperationFactory(txStorage: txStorage, runtimeService: runtimeService)
        case .sora:
            return SoraHistoryOperationFactory(txStorage: AnyDataProviderRepository(txStorage))
        case .none:
            return GiantsquidHistoryOperationFactory(txStorage: txStorage, runtimeService: runtimeService)
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

    func fetchSubqueryHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?>
}
