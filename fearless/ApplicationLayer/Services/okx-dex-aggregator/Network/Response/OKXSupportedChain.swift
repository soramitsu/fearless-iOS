import Foundation

struct OKXSupportedChain: Decodable {
    let chainId: UInt32
    let chainName: String
    let dexTokenApproveAddress: String?
}
