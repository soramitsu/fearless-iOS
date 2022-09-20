import Foundation

struct StakingPoolRoles: Decodable {
    let depositor: AccountId
    let root: AccountId?
    let nominator: AccountId?
    let stateToggler: AccountId?
}
