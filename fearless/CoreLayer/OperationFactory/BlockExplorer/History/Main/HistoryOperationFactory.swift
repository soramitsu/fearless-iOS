
import IrohaCrypto
import RobinHood
import SSFModels
import SSFUtils

enum SubqueryHistoryOperationFactoryError: Error {
    case urlMissing
    case incorrectInputData
}

enum HistoryOperationFactoriesAssembly {
    static func createOperationFactory(
        chain: ChainModel,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    ) -> HistoryOperationFactoryProtocol? {
        let historyUrl = chain.externalApi?.history?.url.absoluteString.lowercased() ?? ""

        if chain.isTonCompatibilityChain {
            return TonHistoryOperationFactory()
        }

        if BitcoinHistoryOperationFactory.supports(chain: chain) {
            return BitcoinHistoryOperationFactory()
        }

        if SolanaHistoryOperationFactory.supports(chain: chain) {
            return SolanaHistoryOperationFactory()
        }

        if IrohaHistoryOperationFactory.supports(chain: chain) {
            return IrohaHistoryOperationFactory()
        }

        if historyUrl.contains("blockscout") {
            return BlockscoutHistoryOperationFactory()
        }

        if let historyURL = chain.externalApi?.history?.url,
           KaiaHistoryOperationFactory.supports(url: historyURL) {
            return KaiaHistoryOperationFactory()
        }

        let historyEndpoint = chain.externalApi?.history?.url
        if ["www.oklink.com", "oklink.com"].contains(historyEndpoint?.host?.lowercased() ?? ""),
           historyEndpoint?.path.hasPrefix("/api/") == true {
            if chain.isEthereumBased, AlchemyHistoryNetwork.identifier(chainId: chain.chainId) != nil {
                return AlchemyHistoryOperationFactory()
            }
            if chain.isEthereumBased, chain.chainId == "43114" {
                return EtherscanHistoryOperationFactory(baseURL: EtherscanHistoryOperationFactory.avalancheHistoryURL)
            }
            return OklinkHistoryOperationFactory()
        }

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
