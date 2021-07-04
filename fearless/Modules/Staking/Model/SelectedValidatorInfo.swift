import Foundation
import BigInt

struct SelectedValidatorInfo: ValidatorInfoProtocol {
    let address: AccountAddress
    let identity: AccountIdentity?
    let stakeInfo: ValidatorStakeInfoProtocol?
    let myNomination: ValidatorMyNominationStatus?
//    let comission: Decimal
    let slashed: Bool
//    let blocked: Bool

    init(
        address: AccountAddress,
        identity: AccountIdentity? = nil,
        stakeInfo: ValidatorStakeInfoProtocol? = nil,
        myNomination: ValidatorMyNominationStatus? = nil,
        slashed: Bool = false
    ) {
        self.address = address
        self.identity = identity
        self.stakeInfo = stakeInfo
        self.myNomination = myNomination
        self.slashed = slashed
    }
}

struct ValidatorStakeInfo: ValidatorStakeInfoProtocol {
    let nominators: [NominatorInfo]
    let totalStake: Decimal
    let stakeReturn: Decimal
    let maxNominatorsRewarded: UInt32

    var oversubscribed: Bool {
        nominators.count > maxNominatorsRewarded
    }

    init(
        nominators: [NominatorInfo] = [],
        totalStake: Decimal = 0.0,
        stakeReturn: Decimal = 0.0,
        maxNominatorsRewarded: UInt32 = 0
    ) {
        self.nominators = nominators
        self.totalStake = totalStake
        self.stakeReturn = stakeReturn
        self.maxNominatorsRewarded = maxNominatorsRewarded
    }
}

enum ValidatorMyNominationStatus {
    case active(amount: Decimal)
    case elected
    case unelected
}
