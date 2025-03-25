import Foundation
import SSFModels
import FearlessKeys

final class CoinbasePurchaseProvivder: PurchaseProviderProtocol {
    enum Constants {
        static let title = "Coinbase"
        static let icon = R.image.iconCoinbase()
    }

    static let baseUrlString = "https://pay.coinbase.com/buy/select-asset"

    private var chainName: String?

    func with(chainName: String) -> Self {
        self.chainName = chainName
        return self
    }

    func buildPurchaseActions(asset: AssetModel, address: String) -> [PurchaseAction] {
        if let url = buildURLForAsset(asset, address: address) {
            return [PurchaseAction(title: Constants.title, url: url, icon: Constants.icon!)]
        }
        return []
    }

    private func buildURLForAsset(_ asset: AssetModel, address: String) -> URL? {
        guard let endpoint = asset.coinbaseUrl?.replacingOccurrences(of: "{address}", with: address) else {
            return nil
        }
        
        var components = URLComponents(string: Self.baseUrlString.appending(endpoint))

        let queryItems = [
            URLQueryItem(name: "appId", value: CoinbaseKeys.coinbaseAppId)
        ]

        components?.queryItems = queryItems

        return components?.url
    }
}
