import Foundation
import SSFModels

/// Opens MoonPay's hosted widget with an unsigned URL. Supplying `walletAddress` requires a
/// signature made with MoonPay's secret key, which belongs on a server, so the wallet leaves the
/// address for the user to enter in MoonPay (`showWalletAddressForm`), as the Android app does.
final class MoonpayProvider: PurchaseProviderProtocol {
    enum Constants {
        static let title = "Moonpay"
        static let icon = R.image.iconMoonPay()
    }

    static let baseUrlString = "https://buy.moonpay.com/"

    private var colorCode: String?
    private var callbackUrl: URL?

    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func with(colorCode: String) -> Self {
        self.colorCode = colorCode
        return self
    }

    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildPurchaseActions(asset: AssetModel, address _: String) -> [PurchaseAction] {
        if let url = buildURLForToken(asset.symbol) {
            return [PurchaseAction(title: Constants.title, url: url, icon: Constants.icon!)]
        }
        return []
    }

    func buildURLForToken(_ token: String) -> URL? {
        guard var components = URLComponents(string: Self.baseUrlString) else { return nil }

        var percentEncodedQueryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "currencyCode", value: token),
            URLQueryItem(name: "showWalletAddressForm", value: "true")
        ]

        if let colorCode = colorCode {
            let percentEncodedValue = colorCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            percentEncodedQueryItems.append(URLQueryItem(name: "colorCode", value: percentEncodedValue))
        }

        if let callbackUrl = callbackUrl?.absoluteString {
            let percentEncodedValue = callbackUrl.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            percentEncodedQueryItems.append(URLQueryItem(name: "redirectURL", value: percentEncodedValue))
        }

        components.percentEncodedQueryItems = percentEncodedQueryItems

        return components.url
    }
}
