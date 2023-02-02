import Foundation

struct SubqueryCreatePoolLiquidity: Decodable {
    let inputAssetA: String
    let inputAssetB: String
    let inputADesired: String
    let inputBDesired: String
}
