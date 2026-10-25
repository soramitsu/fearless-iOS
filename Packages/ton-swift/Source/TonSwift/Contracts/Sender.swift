import Foundation
import BigInt

public struct SenderArguments {
    let value: BigUInt
    let to: Address
    let sendMode: SendMode
    let bounce: Bool
    let stateInit: StateInit?
    let body: Cell
}

public struct Sender {
    let address: Address?
    let send: ((SenderArguments) async throws -> Void)
}
