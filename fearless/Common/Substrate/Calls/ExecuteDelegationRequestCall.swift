import Foundation
import SSFUtils

struct ExecuteDelegationRequestCall: Codable {
    let delegator: AccountId
    let candidate: AccountId
}
