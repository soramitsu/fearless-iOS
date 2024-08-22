import Foundation

struct OKXCrossChainRouter: Decodable {
    let bridgeId: UInt32
    let bridgeName: String
    let crossChainFee: String
    let otherNativeFee: String
    let crossChainFeeTokenAddress: String
}
