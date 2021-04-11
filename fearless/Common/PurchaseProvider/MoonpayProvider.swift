import Foundation
import FearlessUtils
import IrohaCrypto

final class MoonpayProvider: PurchaseProviderProtocol {
    // TODO: FLW-644 Replace with production value
    static let pubToken = "pk_test_DMRuyL6Nf1qc9OzjPBmCFBeCGkFwiZs0"
    static let baseUrlString = "https://buy.moonpay.com/"

    private var colorCode: String?
    private var callbackUrl: URL?

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

    private func calculateHMAC(for query: String) -> String {
        // TODO: FLW-644 Replace with production value
        let hash = query
            .toHMAC(algorithm: .SHA256, key: "sk_test_gv8uZyjSE2ifxhJyEFCGYwNaMntfsdKY")

        let base64Hash =
            try? Data(hexString: hash)
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
        let signature = calculateHMAC(for: query)

        components.percentEncodedQueryItems?.append(URLQueryItem(
            name: "signature",
            value: signature
        ))

        return components.url
    }
}
