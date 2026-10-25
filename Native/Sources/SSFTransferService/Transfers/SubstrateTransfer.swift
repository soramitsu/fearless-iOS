import BigInt
import Foundation
import SSFModels

public struct SubstrateTransfer {
    public let amount: BigUInt
    public let receiver: String
    public let tip: BigUInt?

    public init(
        amount: BigUInt,
        receiver: String,
        tip: BigUInt
    ) {
        self.amount = amount
        self.receiver = receiver
        self.tip = tip
    }
}
