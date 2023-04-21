import Foundation
import SSFUtils

// swiftlint:disable identifier_name
struct PoolNominateCall: Codable {
    let pool_id: String
    let validators: [AccountId]
}
