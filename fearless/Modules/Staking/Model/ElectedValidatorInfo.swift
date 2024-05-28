import Foundation
import IrohaCrypto

struct ElectedValidatorInfo: Equatable, Hashable, Recommendable {
    let address: String
    let nominators: [NominatorInfo]
    let totalStake: Decimal
    let ownStake: Decimal
    let comission: Decimal
    let identity: AccountIdentity?
    let stakeReturn: Decimal
    let hasSlashes: Bool
    let maxNominatorsRewarded: UInt32?
    let blocked: Bool
    let elected: Bool

    var oversubscribed: Bool {
        guard let maxNominatorsRewarded else {
            return false
        }

        return nominators.count > maxNominatorsRewarded
    }

    var hasIdentity: Bool {
        identity != nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(address)
    }
}

struct NominatorInfo: Equatable {
    let address: String
    let stake: Decimal
}

extension ElectedValidatorInfo {
    init(
        validator: EraValidatorInfo,
        identity: AccountIdentity?,
        stakeReturn: Decimal,
        hasSlashes: Bool,
        maxNominatorsRewarded: UInt32?,
        chainFormat: ChainFormat,
        blocked: Bool,
        precision: Int16,
        elected: Bool
    ) throws {
        self.hasSlashes = hasSlashes
        self.identity = identity
        self.stakeReturn = stakeReturn

        address = try AddressFactory.address(
            for: validator.accountId,
            chainFormat: chainFormat
        )
        nominators = try validator.exposure.others.map { nominator in
            let nominatorAddress = try AddressFactory.address(
                for: nominator.who,
                chainFormat: chainFormat
            )
            let stake = Decimal.fromSubstrateAmount(nominator.value, precision: precision) ?? 0.0
            return NominatorInfo(address: nominatorAddress, stake: stake)
        }

        self.maxNominatorsRewarded = maxNominatorsRewarded

        totalStake = Decimal.fromSubstrateAmount(validator.exposure.total, precision: precision) ?? 0.0
        ownStake = Decimal.fromSubstrateAmount(validator.exposure.own, precision: precision) ?? 0.0
        comission = Decimal.fromSubstratePerbill(value: validator.prefs.commission) ?? 0.0

        self.blocked = blocked
        self.elected = elected
    }
}
