import Foundation
import RobinHood
import SSFModels

protocol CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency
    ) -> BaseOperation<[PriceData]>
}

final class CoingeckoOperationFactory {
    private func buildURLForAssets(
        _ tokenIds: [String],
        method: String,
        currency: Currency
    ) -> URL? {
        guard var components = URLComponents(
            url: CoingeckoAPI.baseURL.appendingPathComponent(method),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        let tokenIDParam = tokenIds.joined(separator: ",")
        let currencyParam = currency.id

        components.queryItems = [
            URLQueryItem(name: "ids", value: tokenIDParam),
            URLQueryItem(name: "vs_currencies", value: currencyParam),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]

        return components.url
    }
}

extension CoingeckoOperationFactory: CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency
    ) -> BaseOperation<[PriceData]> {
        guard let url = buildURLForAssets(
            tokenIds,
            method: CoingeckoAPI.price,
            currency: currency
        ) else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
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

        let resultFactory = AnyNetworkResultFactory<[PriceData]> { data in
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

            return tokenIds.compactMap { assetId in
                guard let priceDataJson = json?[assetId] as? [String: Any] else {
                    return nil
                }

                let price = priceDataJson[currency.id] as? CGFloat
                let dayChange = priceDataJson["\(currency.id)_24h_change"] as? CGFloat

                guard let price = price else {
                    return nil
                }

                return PriceData(
                    priceId: assetId,
                    price: String(describing: price),
                    fiatDayChange: Decimal(dayChange ?? 0.0)
                )
            }
        }

        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return operation
    }
}
