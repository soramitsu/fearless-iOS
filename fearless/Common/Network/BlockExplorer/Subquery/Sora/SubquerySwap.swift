import Foundation

struct SubquerySwap: Decodable {
    let baseAssetId: String
    let targetAssetId: String
    let baseAssetAmount: String
    let targetAssetAmount: String
    let selectedMarket: String
}
