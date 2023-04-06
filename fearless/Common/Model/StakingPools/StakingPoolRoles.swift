import Foundation

struct StakingPoolRoles: Decodable {
    let depositor: AccountId
    var root: AccountId?
    var nominator: AccountId?
    var bouncer: AccountId?
}

extension StakingPoolRoles: Equatable {}
