import Foundation
import SSFModels

enum SubqueryPriceFetcherError: Error {
    case missingBlockExplorer(chain: String)
}

protocol SoraSubqueryPriceFetcher {
    func fetch(priceIds: [String]) async throws -> [SoraSubqueryPrice]
}
