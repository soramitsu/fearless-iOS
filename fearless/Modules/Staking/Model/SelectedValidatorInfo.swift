import Foundation

struct SelectedValidatorInfo {
    let address: String
    let identity: AccountIdentity?
    let stakeReturn: Decimal

    init(address: String, identity: AccountIdentity? = nil, stakeReturn: Decimal = 0.0) {
        self.address = address
        self.identity = identity
        self.stakeReturn = stakeReturn
    }
}
