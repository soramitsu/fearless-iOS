import Foundation

struct StakingPoolRoles: Decodable {
    let depositor: AccountId
    var root: AccountId?
    var nominator: AccountId?
    var stateToggler: AccountId?
}

extension StakingPoolRoles: Equatable {}
