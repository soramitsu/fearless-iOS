import Foundation
import SSFModels

final class SoraSubqueryPriceFetcherDefault: SoraSubqueryPriceFetcher {
    private let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    func fetch(priceIds: [String]) async throws -> [SoraSubqueryPrice] {
        var prices: [SoraSubqueryPrice] = []
        var cursor: String = ""
        var allPricesFetched: Bool = false

        while !allPricesFetched {
            let response = try await loadNewPrices(prices: prices, priceIds: priceIds, cursor: cursor)
            prices = prices + response.nodes
            allPricesFetched = response.pageInfo.hasNextPage.or(false) == false
            cursor = response.pageInfo.endCursor.or("")
        }

        return prices
    }

    private func loadNewPrices(
        prices _: [SoraSubqueryPrice],
        priceIds: [String],
        cursor: String
    ) async throws -> SoraSubqueryPricePage {
        guard let blockExplorer = chain.externalApi?.pricing else {
            throw SubqueryPriceFetcherError.missingBlockExplorer(chain: chain.name)
        }

        let request = try StakingRewardsRequest(
            baseURL: blockExplorer.url,
            query: queryString(priceIds: priceIds, cursor: cursor)
        )
        let worker = NetworkWorker()
        let response: GraphQLResponse<SoraSubqueryPriceResponse> = try await worker.performRequest(with: request)

        switch response {
        case let .data(data):
            return data.entities
        case let .errors(error):
            throw error
        }
    }

    private func queryString(priceIds: [String], cursor: String) -> String {
        """
        query FiatPriceQuery {
                  entities: assets(
                    first: 100
                    after: "\(cursor)",
                    filter: {id: {in: \(priceIds)}}) {
                      nodes {
                        id
                        priceUSD
                        priceChangeDay
                      }
                      pageInfo {
                        hasNextPage
                        endCursor
                      }
                    }
            }
        """
    }
}
