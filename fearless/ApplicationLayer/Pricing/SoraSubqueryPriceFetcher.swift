import Foundation
import SSFModels
import RobinHood
import SSFNetwork

final class SoraSubqueryPriceFetcherDefault: SoraSubqueryPriceFetcher {
    private let worker: NetworkWorkerDefault

    init(worker: NetworkWorkerDefault = NetworkWorkerDefault()) {
        self.worker = worker
    }

    func fetchPriceOperation(
        for chainAssets: [ChainAsset]
    ) -> BaseOperation<[PriceData]> {
        AwaitOperation { [weak self] in
            guard let self else { return [] }

            guard let externalApi = chainAssets.first(where: { chainAsset in
                chainAsset.asset.priceProvider?.type == .sorasubquery
            })?.chain.externalApi,
                let priceApi = externalApi.pricing ?? externalApi.history else {
                throw SubqueryPriceFetcherError.missingBlockExplorer
            }
            let priceIds = chainAssets.map { $0.asset.priceProvider?.id }.compactMap { $0 }
            let prices = try await self.fetch(priceIds: priceIds, url: priceApi.url)

            return prices.compactMap { price in
                let chainAsset = chainAssets.first(where: { $0.asset.currencyId == price.id })

                guard
                    let chainAsset = chainAsset,
                    chainAsset.asset.priceProvider?.type == .sorasubquery,
                    let priceId = chainAsset.asset.priceId
                else {
                    return nil
                }

                return PriceData(
                    currencyId: "usd",
                    priceId: priceId,
                    price: "\(price.priceUsd.or("0"))",
                    fiatDayChange: price.priceChangeDay,
                    coingeckoPriceId: chainAsset.asset.coingeckoPriceId
                )
            }
        }
    }

    private func fetch(
        priceIds: [String],
        url: URL
    ) async throws -> [SoraSubqueryPrice] {
        var prices: [SoraSubqueryPrice] = []
        var cursor: String = ""
        var allPricesFetched: Bool = false

        while !allPricesFetched {
            let response = try await loadNewPrices(url: url, priceIds: priceIds, cursor: cursor)
            prices = prices + response.nodes
            allPricesFetched = response.pageInfo.hasNextPage.or(false) == false
            cursor = response.pageInfo.endCursor.or("")
        }

        return prices
    }

    private func loadNewPrices(
        url: URL,
        priceIds: [String],
        cursor: String
    ) async throws -> SoraSubqueryPricePage {
        let request = try StakingRewardsRequest(
            baseURL: url,
            query: SoraSubqueryPriceQueryFactory.queryString(
                priceIds: priceIds,
                cursor: cursor,
                url: url
            )
        )
        let response: GraphQLResponse<SoraSubqueryPriceResponse> = try await worker.performRequest(with: request)

        switch response {
        case let .data(data):
            return data.entities
        case let .errors(error):
            throw error
        }
    }
}

enum SoraSubqueryPriceQueryFactory {
    static func queryString(priceIds: [String], cursor: String, url: URL) -> String {
        if url.host?.lowercased() == "pi.soramitsu.io" {
            return piQueryString(priceIds: priceIds, cursor: cursor)
        }

        return """
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

    private static func piQueryString(priceIds: [String], cursor: String) -> String {
        let after = cursor.isEmpty ? "" : "after: \"\(cursor)\","

        return """
        query FiatPriceQuery {
                  entities: assets(
                    first: 100,
                    \(after)
                    filter: {id: {in: \(priceIds)}}) {
                      edges {
                        node {
                          id
                          priceUSD
                          priceChangeDay
                        }
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
