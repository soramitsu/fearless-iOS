import Foundation

struct AlchemyTokenMetadata: Decodable {
    let decimals: UInt32
    let logo: String?
    let name: String
    let symbol: String
}
