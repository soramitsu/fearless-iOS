
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class HistoryOperationFactoriesAssembly {
    static func createOperationFactory(
        chain: ChainModel,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    ) -> HistoryOperationFactoryProtocol? {
        switch chain.externalApi?.history?.type {
        case .subquery:
            return SubqueryHistoryOperationFactory(txStorage: txStorage, chainRegistry: ChainRegistryFacade.sharedRegistry)
        case .subsquid:
            if chain.isPolkadotOrKusama {
                return ArrowsquidHistoryOperationFactory(txStorage: txStorage)
            } else {
                return SubsquidHistoryOperationFactory(txStorage: txStorage)
            }
        case .giantsquid:
            return GiantsquidHistoryOperationFactory(txStorage: txStorage)
        case .sora:
            return SoraSubsquidHistoryOperationFactory(txStorage: AnyDataProviderRepository(txStorage), chainRegistry: ChainRegistryFacade.sharedRegistry)
        // Alchemy history type removed in SSFModels; use Etherscan when present via explorer
        // or handle via giantsquid/subsquid based on chain configuration.
        case .etherscan:
            return EtherscanHistoryOperationFactory()
        // .oklink case was removed in newer SSFModels; fallback to giantsquid/subsquid routing elsewhere
        case .reef:
            return ReefSubsquidHistoryOperationFactory(txStorage: txStorage)
        // Removed explorers in new enum; fall back to giantsquid/subsquid routing elsewhere
        case .none:
            return nil
        default:
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
