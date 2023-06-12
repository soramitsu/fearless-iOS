import Foundation
import Web3

protocol DelegatorHistoryItem {
    var type: SubqueryDelegationAction { get }
    var blockNumber: Int { get }
    var amount: BigUInt { get }
}
