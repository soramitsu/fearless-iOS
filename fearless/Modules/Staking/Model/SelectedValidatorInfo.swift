import Foundation
import BigInt

struct SelectedValidatorInfo: ValidatorInfoProtocol {
    let address: AccountAddress
    let identity: AccountIdentity?
    let stakeInfo: ValidatorStakeInfoProtocol?
    let myNomination: ValidatorMyNominationStatus?

    init(
        address: AccountAddress,
        identity: AccountIdentity? = nil,
        stakeInfo: ValidatorStakeInfoProtocol? = nil,
        myNomination: ValidatorMyNominationStatus? = nil
    ) {
        self.address = address
        self.identity = identity
        self.stakeInfo = stakeInfo
        self.myNomination = myNomination
    }
}

struct ValidatorStakeInfo: ValidatorStakeInfoProtocol {
    let nominators: [NominatorInfo]
    let totalStake: Decimal
    let stakeReturn: Decimal
    let oversubscribed: Bool

    init(
        nominators: [NominatorInfo] = [],
        totalStake: Decimal = 0.0,
        stakeReturn: Decimal = 0.0,
        oversubscribed: Bool = false
    ) {
        self.nominators = nominators
        self.totalStake = totalStake
        self.stakeReturn = stakeReturn
        self.oversubscribed = oversubscribed
    }
}

enum ValidatorMyNominationStatus {
    case active(amount: Decimal)
    case inactive
    case waiting
    case slashed
}
