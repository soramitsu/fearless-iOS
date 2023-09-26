import Foundation

struct EtherscanNftsResponse: Decodable {
    let status: String?
    let message: String?
    let result: [EtherscanNftResponseElement]?
}
