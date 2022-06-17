import Foundation
import FearlessUtils

struct ExecuteDelegationRequestCall: Codable {
    let delegator: AccountId
    let candidate: AccountId
}
