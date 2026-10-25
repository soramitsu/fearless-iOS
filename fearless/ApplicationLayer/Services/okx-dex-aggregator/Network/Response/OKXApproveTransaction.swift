import Foundation

struct OKXApproveTransaction: Decodable {
    let data: String
    let dexContractAddress: String
    let gasLimit: String
    let gasPrice: String
}
