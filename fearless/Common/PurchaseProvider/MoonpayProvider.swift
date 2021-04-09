import Foundation
import FearlessUtils
import CommonCrypto.CommonHMAC

final class MoonpayProvider: PurchaseProviderProtocol {
    // TODO: FLW-644 Replace with production value
    static let pubToken = "pk_test_DMRuyL6Nf1qc9OzjPBmCFBeCGkFwiZs0"
    static let baseUrlString = "https://buy.moonpay.com/"

    private var colorCode: String?
    private var callbackUrl: URL?

    func with(appName _: String) -> Self {
        self
    }

    func with(logoUrl _: URL) -> Self {
        self
    }

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

    private func buildURLForToken(_ token: String, address: String) -> URL? {
        var components = URLComponents(string: Self.baseUrlString)

        var queryItems = [
            URLQueryItem(name: "apiKey", value: Self.pubToken),
            URLQueryItem(name: "currencyCode", value: token),
            URLQueryItem(name: "walletAddress", value: address),
            URLQueryItem(name: "showWalletAddressForm", value: "true")
        ]

        if let colorCode = colorCode {
            let percentEncodedValue = colorCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            queryItems.append(URLQueryItem(name: "colorCode", value: percentEncodedValue))
        }

        if let callbackUrl = callbackUrl?.absoluteString {
            let percentEncodedValue = callbackUrl.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            queryItems.append(URLQueryItem(name: "redirectURL", value: percentEncodedValue))
        }

        components?.percentEncodedQueryItems = queryItems

        let query = "?\(components?.percentEncodedQuery ?? "")"
        
        // TODO: FLW-644 Replace with production value
        let hash = query
            .toHMAC(algorithm: .SHA256, key: "sk_test_gv8uZyjSE2ifxhJyEFCGYwNaMntfsdKY")
        let base64Hash =
            Data(hash.utf8)
                .base64EncodedString()
                .addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "+/=").inverted)

        components?.percentEncodedQueryItems?.append(URLQueryItem(name: "signature", value: base64Hash))

        return components?.url
    }
}
