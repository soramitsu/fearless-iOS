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
    let maxNominatorsRewarded: UInt32
    let blocked: Bool

    var oversubscribed: Bool {
        nominators.count > maxNominatorsRewarded
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
        maxNominatorsRewarded: UInt32,
        addressType: SNAddressType,
        blocked: Bool
    ) throws {
        self.hasSlashes = hasSlashes
        self.identity = identity
        self.stakeReturn = stakeReturn

        let addressFactory = SS58AddressFactory()

        address = try addressFactory.addressFromAccountId(data: validator.accountId, type: addressType)
        nominators = try validator.exposure.others.map { nominator in
            let nominatorAddress = try addressFactory.addressFromAccountId(
                data: nominator.who,
                type: addressType
            )
            let stake = Decimal.fromSubstrateAmount(nominator.value, precision: addressType.precision) ?? 0.0
            return NominatorInfo(address: nominatorAddress, stake: stake)
        }

        self.maxNominatorsRewarded = maxNominatorsRewarded

        totalStake = Decimal.fromSubstrateAmount(validator.exposure.total, precision: addressType.precision) ?? 0.0
        ownStake = Decimal.fromSubstrateAmount(validator.exposure.own, precision: addressType.precision) ?? 0.0
        comission = Decimal.fromSubstratePerbill(value: validator.prefs.commission) ?? 0.0

        self.blocked = blocked
    }
}
