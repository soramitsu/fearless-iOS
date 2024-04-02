import Foundation
import BigInt

struct SwapValues: Decodable {
    var dexId: UInt32?
    let amount: String
    let rewards: [String]

    enum CodingKeys: String, CodingKey {
        case amount
        case rewards
    }
}

struct SubstrateSwapValues: Decodable {
    static let mockSwapValues = SubstrateSwapValues(amount: .zero, rewards: [])

    var dexId: UInt32?
    let amount: BigUInt
    let rewards: [String]
}
