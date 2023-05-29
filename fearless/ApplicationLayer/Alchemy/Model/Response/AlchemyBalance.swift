import Foundation

struct AlchemyContractBalance: Decodable {
    let contractAddress: String
    let tokenBalance: String
}

struct AlchemyBalance: Decodable {
    let address: String
    let tokenBalances: [AlchemyContractBalance]
}
