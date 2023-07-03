import Foundation
import IrohaCrypto
import SSFModels

final class NominatorPayoutInfoFactory: PayoutInfoFactoryProtocol {
    let addressPrefix: UInt16
    let precision: Int16
    let chainAsset: ChainAsset

    init(addressPrefix: UInt16, precision: Int16, chainAsset: ChainAsset) {
        self.precision = precision
        self.addressPrefix = addressPrefix
        self.chainAsset = chainAsset
    }

    func calculate(
        for accountId: AccountId,
        era: EraIndex,
        validatorInfo: EraValidatorInfo,
        erasRewardDistribution: ErasRewardDistribution,
        identities: [AccountAddress: AccountIdentity]
    ) throws -> PayoutInfo? {
        guard
            let totalRewardAmount = erasRewardDistribution.totalValidatorRewardByEra[era],
            let totalReward = Decimal.fromSubstrateAmount(totalRewardAmount, precision: precision),
            let points = erasRewardDistribution.validatorPointsDistributionByEra[era] else {
            return nil
        }

        guard
            let nominatorStakeAmount = validatorInfo.exposure.others
            .first(where: { $0.who == accountId })?.value,
            let nominatorStake = Decimal
            .fromSubstrateAmount(nominatorStakeAmount, precision: precision),
            let comission = Decimal.fromSubstratePerbill(value: validatorInfo.prefs.commission),
            let validatorPoints = points.individual
            .first(where: { $0.accountId == validatorInfo.accountId })?.rewardPoint,
            let totalStake = Decimal
            .fromSubstrateAmount(validatorInfo.exposure.total, precision: precision) else {
            return nil
        }

        let rewardFraction = Decimal(validatorPoints) / Decimal(points.total)
        let validatorTotalReward = totalReward * rewardFraction
        let nominatorReward = validatorTotalReward * (1 - comission) *
            (nominatorStake / totalStake)

        let validatorAddress = try AddressFactory.address(
            for: validatorInfo.accountId,
            chainFormat: chainAsset.chain.chainFormat
        )

        return PayoutInfo(
            era: era,
            validator: validatorInfo.accountId,
            reward: nominatorReward,
            identity: identities[validatorAddress]
        )
    }
}
