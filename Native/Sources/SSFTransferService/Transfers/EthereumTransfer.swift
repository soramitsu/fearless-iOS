import BigInt
import Foundation
import SSFModels

public struct EthereumTransfer {
    public let amount: BigUInt
    public let receiver: String

    public init(
        amount: BigUInt,
        receiver: String
    ) {
        self.amount = amount
        self.receiver = receiver
    }
}
