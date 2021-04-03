import Foundation

struct SelectedValidatorInfo: ValidatorInfoProtocol {
    let address: AccountAddress
    let identity: AccountIdentity?
    let stakeInfo: ValidatorStakeInfoProtocol?

    init(
        address: AccountAddress,
        identity: AccountIdentity? = nil,
        stakeInfo: ValidatorStakeInfoProtocol? = nil
    ) {
        self.address = address
        self.identity = identity
        self.stakeInfo = stakeInfo
    }
}

struct ValidatorStakeInfo: ValidatorStakeInfoProtocol {
    let nominators: [NominatorInfo]
    let totalStake: Decimal
    let stakeReturn: Decimal

    init(
        nominators: [NominatorInfo] = [],
        totalStake: Decimal = 0.0,
        stakeReturn: Decimal = 0.0
    ) {
        self.nominators = nominators
        self.totalStake = totalStake
        self.stakeReturn = stakeReturn
    }
}
