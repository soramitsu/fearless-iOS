import Foundation
import BigInt

protocol EthBlockChangesListener: AnyObject {
    func didReceive(baseFeePerGas: BigUInt)
    func didFailToSubscribe(error: Error)
}
