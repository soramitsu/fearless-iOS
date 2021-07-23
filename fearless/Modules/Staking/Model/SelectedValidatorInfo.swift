import Foundation
import BigInt

struct SelectedValidatorInfo: ValidatorInfoProtocol, Equatable, Recommendable {
    let address: AccountAddress
    let identity: AccountIdentity?
    let stakeInfo: ValidatorStakeInfoProtocol?
    let myNomination: ValidatorMyNominationStatus?
    let commission: Decimal
    let hasSlashes: Bool
    let blocked: Bool

    var oversubscribed: Bool {
        stakeInfo?.oversubscribed ?? false
    }

    var hasIdentity: Bool {
        identity != nil
    }

    var stakeReturn: Decimal {
        stakeInfo?.stakeReturn ?? 0.0
    }

    var totalStake: Decimal {
        stakeInfo?.totalStake ?? 0.0
    }

    var ownStake: Decimal {
        stakeInfo?.ownStake ?? 0.0
    }

    init(
        address: AccountAddress,
        identity: AccountIdentity? = nil,
        stakeInfo: ValidatorStakeInfoProtocol? = nil,
        myNomination: ValidatorMyNominationStatus? = nil,
        commission: Decimal = 0.0,
        hasSlashes: Bool = false,
        blocked: Bool = false
    ) {
        self.address = address
        self.identity = identity
        self.stakeInfo = stakeInfo
        self.myNomination = myNomination
        self.commission = commission
        self.hasSlashes = hasSlashes
        self.blocked = blocked
    }

    static func == (lhs: SelectedValidatorInfo, rhs: SelectedValidatorInfo) -> Bool {
        lhs.address == rhs.address
    }
}

struct ValidatorStakeInfo: ValidatorStakeInfoProtocol {
    let nominators: [NominatorInfo]
    let totalStake: Decimal
    let ownStake: Decimal
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

        ownStake = totalStake - nominators.map(\.stake).reduce(0, +)
    }
}

struct ValidatorTokenAllocation {
    let amount: Decimal
    let isRewarded: Bool
}

enum ValidatorMyNominationStatus {
    case active(allocation: ValidatorTokenAllocation)
    case elected
    case unelected
}
