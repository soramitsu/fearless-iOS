import Foundation
import IrohaCrypto

final class NominatorPayoutsInfoFactory {
    let accountId: Data
    let addressType: SNAddressType
    let erasRewardDistribution: ErasRewardDistribution
    let identities: [AccountAddress: AccountIdentity]
    let addressFactory: SS58AddressFactoryProtocol

    init(
        accountId: Data,
        addressType: SNAddressType,
        erasRewardDistribution: ErasRewardDistribution,
        identities: [AccountAddress: AccountIdentity],
        addressFactory: SS58AddressFactoryProtocol
    ) {
        self.accountId = accountId
        self.addressType = addressType
        self.erasRewardDistribution = erasRewardDistribution
        self.identities = identities
        self.addressFactory = addressFactory
    }

    func calculate(for era: EraIndex, validatorInfo: EraValidatorInfo) throws -> PayoutInfo? {
        guard
            let totalRewardAmount = erasRewardDistribution.totalValidatorRewardByEra[era],
            let totalReward = Decimal.fromSubstrateAmount(totalRewardAmount, precision: addressType.precision),
            let points = erasRewardDistribution.validatorPointsDistributionByEra[era] else {
            return nil
        }

        guard
            let nominatorStakeAmount = validatorInfo.exposure.others
            .first(where: { $0.who == accountId })?.value,
            let nominatorStake = Decimal
            .fromSubstrateAmount(nominatorStakeAmount, precision: addressType.precision),
            let comission = Decimal.fromSubstratePerbill(value: validatorInfo.prefs.commission),
            let validatorPoints = points.individual
            .first(where: { $0.accountId == validatorInfo.accountId })?.rewardPoint,
            let totalStake = Decimal
            .fromSubstrateAmount(validatorInfo.exposure.total, precision: addressType.precision) else {
            return nil
        }

        let rewardFraction = Decimal(validatorPoints) / Decimal(points.total)
        let validatorTotalReward = totalReward * rewardFraction
        let nominatorReward = validatorTotalReward * (1 - comission) *
            (nominatorStake / totalStake)

        let validatorAddress = try addressFactory
            .addressFromAccountId(data: validatorInfo.accountId, type: addressType)

        return PayoutInfo(
            era: era,
            validator: validatorInfo.accountId,
            reward: nominatorReward,
            identity: identities[validatorAddress]
        )
    }
}
