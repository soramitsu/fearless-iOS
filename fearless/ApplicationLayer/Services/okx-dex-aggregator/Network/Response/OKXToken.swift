import Foundation

struct OKXToken: Decodable {
    let decimals: String
    let tokenContractAddress: String
    let tokenLogoUrl: String
    let tokenName: String
    let tokenSymbol: String
}
