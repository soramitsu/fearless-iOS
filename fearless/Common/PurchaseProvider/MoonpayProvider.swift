import Foundation
import SSFUtils
import IrohaCrypto
import SSFModels

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

    var hmacSigner: HmacSignerProtocol?

    func with(colorCode: String) -> Self {
        self.colorCode = colorCode
        return self
    }

    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildPurchaseActions(asset: AssetModel, address: String) -> [PurchaseAction] {
        if let url = buildURLForToken(asset.symbol, address: address) {
            return [PurchaseAction(title: Constants.title, url: url, icon: Constants.icon!)]
        }
        return []
    }

    private func calculateHmac(for query: String) throws -> String {
        guard let signer = hmacSigner else { return "" }
        let queryData = Data(query.utf8)
        let signatureData = try signer.sign(queryData)

        let base64Hash =
            signatureData
                .base64EncodedString()
                .addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "+/=").inverted)

        return base64Hash ?? ""
    }

    private func buildURLForToken(_ token: String, address: String) -> URL? {
        guard var components = URLComponents(string: Self.baseUrlString) else { return nil }

        var percentEncodedQueryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "currencyCode", value: token),
            URLQueryItem(name: "walletAddress", value: address),
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

        let percentEncodedQuery = components.percentEncodedQuery ?? ""
        let query = "?\(percentEncodedQuery)"
        let signature = try? calculateHmac(for: query)

        components.percentEncodedQueryItems?.append(URLQueryItem(
            name: "signature",
            value: signature ?? ""
        ))

        return components.url
    }
}
