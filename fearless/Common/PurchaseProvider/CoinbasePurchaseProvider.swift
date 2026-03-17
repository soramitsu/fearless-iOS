import Foundation
import SSFModels

final class CoinbasePurchaseProvider: PurchaseProviderProtocol {
    enum Constants {
        static let title = "Coinbase"
        static let icon = R.image.iconBuy()
        static let baseUrlString = "https://pay.coinbase.com/buy/select-asset"
    }

    private struct AssetConfiguration {
        let network: String
        let assetCodes: [String]
    }

    // Map of supported assets and the Coinbase network identifiers they use.
    private static let supportedAssets: [String: AssetConfiguration] = [
        "DOT": AssetConfiguration(network: "polkadot", assetCodes: ["DOT"])
    ]

    func buildPurchaseActions(asset: AssetModel, address: String) -> [PurchaseAction] {
        guard let endpointConfiguration = Self.configuration(for: asset) else {
            return []
        }

        guard let url = buildUrl(
            for: endpointConfiguration,
            replacingAddressTemplateWith: address
        ) else {
            return []
        }

        guard let icon = Constants.icon else {
            return []
        }

        return [PurchaseAction(title: Constants.title, url: url, icon: icon)]
    }

    private static func configuration(for asset: AssetModel) -> AssetConfiguration? {
        supportedAssets[asset.symbol.uppercased()]
    }

    private func buildUrl(for configuration: AssetConfiguration, replacingAddressTemplateWith address: String) -> URL? {
        var components = URLComponents(string: Constants.baseUrlString)

        let addressesValue = """
        {"\(address)":["\(configuration.network)"]}
        """

        let assetsValue = "[\(configuration.assetCodes.map { "\"\($0)\"" }.joined(separator: ","))]"

        var queryItems = [
            URLQueryItem(name: "addresses", value: addressesValue),
            URLQueryItem(name: "assets", value: assetsValue),
            URLQueryItem(name: "appId", value: CoinbaseKeys.appId)
        ]

        if let existingItems = components?.queryItems {
            queryItems.append(contentsOf: existingItems)
        }

        components?.queryItems = queryItems

        return components?.url
    }
}
