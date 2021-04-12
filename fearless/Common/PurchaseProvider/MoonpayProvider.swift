import Foundation
import FearlessUtils
import IrohaCrypto

final class MoonpayProvider: PurchaseProviderProtocol {
    static let pubToken = "pk_live_Boi6Rl107p7XuJWBL8GJRzGWlmUSoxbz"
    static let baseUrlString = "https://buy.moonpay.com/"

    private var colorCode: String?
    private var callbackUrl: URL?

    var hmacSigner: HmacSignerProtocol?

    func with(colorCode: String) -> Self {
        self.colorCode = colorCode
        return self
    }

    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildPurchaseAction(
        for chain: Chain,
        assetId _: WalletAssetId?,
        address: String
    ) -> [PurchaseAction] {
        let optionUrl: URL?

        switch chain {
        case .polkadot:
            optionUrl = buildURLForToken("DOT", address: address)
        case .kusama:
            optionUrl = nil
        case .westend:
            optionUrl = nil
        }

        if let url = optionUrl {
            let action = PurchaseAction(title: "MoonPay", url: url, icon: R.image.iconMoonPay()!)
            return [action]
        } else {
            return []
        }
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
            URLQueryItem(name: "apiKey", value: Self.pubToken),
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
