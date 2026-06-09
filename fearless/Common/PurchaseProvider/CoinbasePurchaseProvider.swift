import Foundation
import UIKit.UIImage
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

    private let sessionTokenProvider: () -> String?
    private let iconProvider: () -> UIImage?

    init(
        sessionTokenProvider: @escaping () -> String? = { CoinbaseKeys.sessionToken },
        iconProvider: @escaping () -> UIImage? = { Constants.icon }
    ) {
        self.sessionTokenProvider = sessionTokenProvider
        self.iconProvider = iconProvider
    }

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

        guard let icon = iconProvider() else {
            return []
        }

        return [PurchaseAction(title: Constants.title, url: url, icon: icon)]
    }

    private static func configuration(for asset: AssetModel) -> AssetConfiguration? {
        supportedAssets[asset.symbol.uppercased()]
    }

    private func buildUrl(for configuration: AssetConfiguration, replacingAddressTemplateWith address: String) -> URL? {
        var components = URLComponents(string: Constants.baseUrlString)
        guard let sessionToken = sessionTokenProvider() else {
            return nil
        }

        var queryItems = [
            URLQueryItem(name: "sessionToken", value: sessionToken),
            URLQueryItem(name: "defaultNetwork", value: configuration.network),
            URLQueryItem(name: "defaultAsset", value: configuration.assetCodes.first),
            URLQueryItem(name: "partnerUserRef", value: address)
        ]

        if let existingItems = components?.queryItems {
            queryItems.append(contentsOf: existingItems)
        }

        components?.queryItems = queryItems

        return components?.url
    }
}
