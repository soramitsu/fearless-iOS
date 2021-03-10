import Foundation

struct ValidatorInfo: ValidatorInfoProtocol {
    let address: String
    let identity: AccountIdentity?
    let stakeInfo: ValidatorStakeInfoProtocol?
}

struct ValidatorStakeInfo: ValidatorStakeInfoProtocol {
    let nominators: [NominatorInfo]
    let totalStake: Decimal
    let stakeReturn: Decimal
}
