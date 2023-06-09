import Foundation
import IrohaCrypto
import SSFModels

final class ValidatorPayoutInfoFactory: PayoutInfoFactoryProtocol {
    let chain: ChainModel
    let asset: AssetModel

    init(chain: ChainModel, asset: AssetModel) {
        self.chain = chain
        self.asset = asset
    }

    func calculate(
        for _: AccountId,
        era: EraIndex,
        validatorInfo: EraValidatorInfo,
        erasRewardDistribution: ErasRewardDistribution,
        identities: [AccountAddress: AccountIdentity]
    ) throws -> PayoutInfo? {
        guard
            let totalRewardAmount = erasRewardDistribution.totalValidatorRewardByEra[era],
            let totalReward = Decimal.fromSubstrateAmount(totalRewardAmount, precision: Int16(asset.precision)),
            let points = erasRewardDistribution.validatorPointsDistributionByEra[era] else {
            return nil
        }

        guard
            let ownStake = Decimal
            .fromSubstrateAmount(validatorInfo.exposure.own, precision: Int16(asset.precision)),
            let comission = Decimal.fromSubstratePerbill(value: validatorInfo.prefs.commission),
            let validatorPoints = points.individual
            .first(where: { $0.accountId == validatorInfo.accountId })?.rewardPoint,
            let totalStake = Decimal
            .fromSubstrateAmount(validatorInfo.exposure.total, precision: Int16(asset.precision)) else {
            return nil
        }

        let rewardFraction = Decimal(validatorPoints) / Decimal(points.total)
        let validatorTotalReward = totalReward * rewardFraction
        let stakeReward = validatorTotalReward * (1 - comission) *
            (ownStake / totalStake)
        let commissionReward = validatorTotalReward * comission

        let validatorAddress = try AddressFactory
            .address(for: validatorInfo.accountId, chainFormat: chain.chainFormat)

        return PayoutInfo(
            era: era,
            validator: validatorInfo.accountId,
            reward: commissionReward + stakeReward,
            identity: identities[validatorAddress]
        )
    }
}
