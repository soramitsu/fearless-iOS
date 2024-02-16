import Foundation
import BigInt

protocol LockProtocol {
    var amount: BigUInt { get }
    var lockType: String? { get }
}
