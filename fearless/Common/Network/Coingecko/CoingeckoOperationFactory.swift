import Foundation
import RobinHood

protocol CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(for assets: [WalletAssetId]) -> BaseOperation<PriceData?>
}

struct CoingeckoPriceRequestOptions: OptionSet {
    let rawValue: Int

    static let includeMarketCap = CoingeckoPriceRequestOptions(rawValue: 1 << 0)
    static let includeDayVolume = CoingeckoPriceRequestOptions(rawValue: 1 << 1)
    static let includeDayChange = CoingeckoPriceRequestOptions(rawValue: 1 << 2)
    static let includeLastUpdatedAt = CoingeckoPriceRequestOptions(rawValue: 1 << 3)

    static let all: CoingeckoPriceRequestOptions = [
        .includeMarketCap,
        .includeDayVolume,
        .includeDayChange,
        .includeLastUpdatedAt
    ]

    static let none: CoingeckoPriceRequestOptions = []
}

final class CoingeckoOperationFactory {
    static let baseUrlString = "https://api.coingecko.com/api/v3"

    private func buildURLForAssets(
        _ assets: [WalletAssetId],
        method: String,
        currencies: [String] = ["usd"],
        options: CoingeckoPriceRequestOptions = [.includeDayChange, .includeLastUpdatedAt]
    ) -> URL? {
        guard var components = URLComponents(
            string: Self.baseUrlString + method
        ) else { return nil }

        let tokenIDParam = assets.compactMap(\.coingeckoTokenId).joined(separator: ",")
        let currencyParam = currencies.joined(separator: ",")

        components.queryItems = [
            URLQueryItem(name: "ids", value: tokenIDParam),
            URLQueryItem(name: "vs_currencies", value: currencyParam)
        ]

        if options.contains(.includeMarketCap) {
            components.queryItems?.append(URLQueryItem(name: "include_market_cap", value: "true"))
        }

        if options.contains(.includeDayVolume) {
            components.queryItems?.append(URLQueryItem(name: "include_24hr_vol", value: "true"))
        }

        if options.contains(.includeDayChange) {
            components.queryItems?.append(URLQueryItem(name: "include_24hr_change", value: "true"))
        }

        if options.contains(.includeLastUpdatedAt) {
            components.queryItems?.append(URLQueryItem(name: "include_last_updated_at", value: "true"))
        }

        return components.url
    }
}

extension CoingeckoOperationFactory: CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(for assets: [WalletAssetId]) -> BaseOperation<PriceData?> {
        guard assets.count == 1 else {
            return BaseOperation.createWithError(CoingeckoError.multipleAssetsNotSupported)
        }

        guard let url = buildURLForAssets(assets, method: CoingeckoAPI.price) else {
            return BaseOperation.createWithError(CoingeckoError.cantBuildURL)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<PriceData?> { data in
            let priceData = try JSONDecoder().decode(
                CoingeckoPriceData.self,
                from: data
            )

            return priceData.assetPriceList.first
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
