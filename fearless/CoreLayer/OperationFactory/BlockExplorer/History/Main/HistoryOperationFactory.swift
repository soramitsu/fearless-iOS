import CommonWallet
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
        case .alchemy:
            return AlchemyHistoryOperationFactory(txStorage: txStorage, alchemyService: AlchemyService())
        case .etherscan:
            return EtherscanHistoryOperationFactory()
        case .oklink:
            return OklinkHistoryOperationFactory()
        case .reef:
            return ReefSubsquidHistoryOperationFactory(txStorage: txStorage)
        case .zeta:
            return ZetaHistoryOperationFactory()
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
