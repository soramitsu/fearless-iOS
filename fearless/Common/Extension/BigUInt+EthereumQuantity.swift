import Foundation
import BigInt
import Web3

extension BigUInt {
    func toEthereumQuantity() -> EthereumQuantity {
        EthereumQuantity(quantity: self)
    }
}
