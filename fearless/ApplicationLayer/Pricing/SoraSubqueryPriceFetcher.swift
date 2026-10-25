import Foundation
import SSFModels
import RobinHood
import SSFNetwork

final class SoraSubqueryPriceFetcherDefault: SoraSubqueryPriceFetcher {
    private enum Constants {
        static let pageSize = 100
        static let maximumPages = 20
        static let maximumCursorBytes = 4096
        static let maximumIdentifierBytes = 4096
        static let maximumPriceBytes = 256
        static let maximumRequestBytes = 256 * 1024
    }

    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = ApplicationConfig.shared.polkaswapIndexerURL,
        session: URLSession? = nil
    ) {
        self.endpoint = endpoint
        self.session = session ?? Self.makeSession()
    }

    func fetchPriceOperation(
        for chainAssets: [ChainAsset]
    ) -> BaseOperation<[PriceData]> {
        AwaitOperation { [weak self] in
            guard let self else { return [] }

            try self.validateEndpoint()

            let soraChainAssets = chainAssets.filter {
                $0.asset.priceProvider?.type == .sorasubquery
            }

            guard soraChainAssets.isNotEmpty else {
                return []
            }

            var chainAssetsByPriceId: [String: ChainAsset] = [:]
            for chainAsset in soraChainAssets {
                guard let priceId = chainAsset.asset.priceProvider?.id else {
                    continue
                }

                try self.validatePriceIdentifier(priceId)
                if chainAssetsByPriceId[priceId] == nil {
                    chainAssetsByPriceId[priceId] = chainAsset
                }
            }

            let priceIds = chainAssetsByPriceId.keys.sorted()
            let prices = try await self.fetch(priceIds: priceIds)

            return prices.compactMap { price in
                guard
                    let chainAsset = chainAssetsByPriceId[price.id],
                    let priceUsd = price.priceUsd,
                    PriceValueValidator.isStrictlyPositiveDecimal(
                        priceUsd,
                        maximumBytes: Constants.maximumPriceBytes
                    ),
                    let priceId = chainAsset.asset.priceId
                else {
                    return nil
                }

                return PriceData(
                    currencyId: "usd",
                    priceId: priceId,
                    price: priceUsd,
                    fiatDayChange: price.priceChangeDay,
                    coingeckoPriceId: chainAsset.asset.coingeckoPriceId
                )
            }
        }
    }

    private func fetch(
        priceIds: [String]
    ) async throws -> [SoraSubqueryPrice] {
        var prices: [SoraSubqueryPrice] = []
        var cursor: String?
        var seenCursors = Set<String>()
        var seenPriceIds = Set<String>()
        let requestedPriceIds = Set(priceIds)

        for _ in 0 ..< Constants.maximumPages {
            let response = try await loadNewPrices(priceIds: priceIds, cursor: cursor)

            for price in response.nodes {
                guard
                    requestedPriceIds.contains(price.id),
                    seenPriceIds.insert(price.id).inserted
                else {
                    throw SubqueryPriceFetcherError.invalidResponse
                }
                prices.append(price)
            }

            guard let hasNextPage = response.pageInfo.hasNextPage else {
                throw SubqueryPriceFetcherError.invalidResponse
            }

            if !hasNextPage {
                return prices
            }

            guard
                response.nodes.isNotEmpty,
                let endCursor = response.pageInfo.endCursor,
                endCursor.isNotEmpty,
                endCursor.utf8.count <= Constants.maximumCursorBytes,
                seenCursors.insert(endCursor).inserted
            else {
                throw SubqueryPriceFetcherError.invalidPagination
            }
            cursor = endCursor
        }

        throw SubqueryPriceFetcherError.paginationLimit
    }

    private func loadNewPrices(
        priceIds: [String],
        cursor: String?
    ) async throws -> SoraSubqueryPricePage {
        let request = try PolkaswapPriceRequest(
            baseURL: endpoint,
            priceIds: priceIds,
            cursor: cursor,
            pageSize: Constants.pageSize,
            maximumBodyBytes: Constants.maximumRequestBytes
        )
        let worker = NetworkWorkerDefault(session: session)
        let response: GraphQLResponse<SoraSubqueryPriceResponse> = try await worker.performRequest(with: request)

        switch response {
        case let .data(data):
            return data.entities
        case let .errors(error):
            throw error
        }
    }

    private func validateEndpoint() throws {
        guard
            endpoint == ApplicationConfig.shared.polkaswapIndexerURL,
            endpoint.absoluteString == "https://pi.soramitsu.io/graphql"
        else {
            throw SubqueryPriceFetcherError.invalidEndpoint
        }
    }

    private func validatePriceIdentifier(_ identifier: String) throws {
        guard
            identifier.isNotEmpty,
            identifier == identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            identifier.utf8.count <= Constants.maximumIdentifierBytes
        else {
            throw SubqueryPriceFetcherError.invalidPriceIdentifier
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        return URLSession(
            configuration: configuration,
            delegate: PolkaswapRedirectRejectingDelegate.shared,
            delegateQueue: nil
        )
    }
}

private final class PolkaswapPriceRequest: RequestConfig {
    private struct Body: Encodable {
        struct Variables: Encodable {
            let first: Int
            let after: String?
            let ids: [String]
        }

        let operationName: String
        let query: String
        let variables: Variables
    }

    private static let query = """
    query FearlessFiatPrices($first: Int!, $after: Cursor, $ids: [String!]!) {
      entities: assets(
        first: $first
        after: $after
        filter: {id: {in: $ids}}
        orderBy: [ID_ASC]
      ) {
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

    init(
        baseURL: URL,
        priceIds: [String],
        cursor: String?,
        pageSize: Int,
        maximumBodyBytes: Int
    ) throws {
        let body = try JSONEncoder().encode(
            Body(
                operationName: "FearlessFiatPrices",
                query: Self.query,
                variables: Body.Variables(
                    first: pageSize,
                    after: cursor,
                    ids: priceIds
                )
            )
        )

        guard body.count <= maximumBodyBytes else {
            throw SubqueryPriceFetcherError.requestTooLarge
        }

        super.init(
            baseURL: baseURL,
            method: .post,
            endpoint: nil,
            headers: [
                HTTPHeader(
                    field: HttpHeaderKey.contentType.rawValue,
                    value: HttpContentType.json.rawValue
                )
            ],
            body: body
        )
    }
}

private final class PolkaswapRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = PolkaswapRedirectRejectingDelegate()

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
