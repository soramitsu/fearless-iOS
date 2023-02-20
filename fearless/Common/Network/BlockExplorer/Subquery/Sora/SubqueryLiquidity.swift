import Foundation

struct SubqueryLiquidity: Decodable {
    let baseAssetId: String
    let targetAssetId: String
    let targetAssetAmount: String
    let baseAssetAmount: String
    let type: TransactionLiquidityType
}

enum TransactionLiquidityType: String, Decodable {
    case deposit = "Deposit"
    case removal = "Removal"
}
