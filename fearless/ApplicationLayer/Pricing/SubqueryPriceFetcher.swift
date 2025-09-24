import Foundation
import SSFModels
import RobinHood

enum SubqueryPriceFetcherError: Error {
    case missingBlockExplorer
}

protocol SoraSubqueryPriceFetcher {
    func fetchPriceOperation(
        for chainAssets: [ChainAsset]
    ) -> BaseOperation<[PriceData]>
}
