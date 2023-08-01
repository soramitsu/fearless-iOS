import Foundation
import BigInt

protocol DelegatorHistoryItem {
    var type: SubqueryDelegationAction { get }
    var blockNumber: Int { get }
    var amount: BigUInt { get }
}
