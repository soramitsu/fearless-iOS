import Foundation
import SSFModels

final class RampProvider: PurchaseProviderProtocol {
    enum Constants {
        static let title = "Ramp"
        static let icon = R.image.iconRamp()
    }

    static let baseUrlString = "https://app.ramp.network/"

    private let hostApiKey: String
    private var appName: String?
    private var logoUrl: URL?
    private var callbackUrl: URL?

    init(hostApiKey: String = RampCIKeys.hostApiKey) {
        self.hostApiKey = hostApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func with(appName: String) -> Self {
        self.appName = appName
        return self
    }

    func with(logoUrl: URL) -> Self {
        self.logoUrl = logoUrl
        return self
    }

    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildPurchaseActions(asset: AssetModel, address: String) -> [PurchaseAction] {
        guard !hostApiKey.isEmpty else {
            return []
        }

        if let url = buildURLForToken(asset.symbolUppercased, address: address) {
            return [PurchaseAction(title: Constants.title, url: url, icon: Constants.icon!)]
        }
        return []
    }

    private func buildURLForToken(_ token: String, address: String) -> URL? {
        var components = URLComponents(string: Self.baseUrlString)

        var queryItems = [
            URLQueryItem(name: "swapAsset", value: token.uppercased()),
            URLQueryItem(name: "userAddress", value: address),
            URLQueryItem(name: "hostApiKey", value: hostApiKey),
            URLQueryItem(name: "variant", value: "hosted-mobile")
        ]

        if let callbackUrl = callbackUrl?.absoluteString {
            queryItems.append(URLQueryItem(name: "finalUrl", value: callbackUrl))
        }

        if let appName = appName {
            queryItems.append(URLQueryItem(name: "hostAppName", value: appName))
        }

        if let logoUrl = logoUrl?.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            queryItems.append(URLQueryItem(name: "hostLogoUrl", value: logoUrl))
        }

        components?.queryItems = queryItems

        return components?.url
    }
}
