import BigInt
import Foundation
import SSFModels
import SSFStorageQueryKit
import SSFUtils

/// The past eras' total stake, reward points and validator rewards the SORA reward calculator estimates from.
struct SoraEraRewardHistory {
    let totalStakeByEra: [EraIndex: BigUInt]
    let rewardPointsByEra: [EraIndex: EraRewardPoints]
    let validatorRewardsByEra: [EraIndex: BigUInt]

    static func fetch(
        _ performer: SSFStorageQueryKit.StorageRequestPerformer,
        chain: ChainModel
    ) async throws -> SoraEraRewardHistory {
        async let totalStake: [String: StringScaleMapper<BigUInt>]? = try await performer.performPrefix(
            StakingErasTotalStakeRequest(),
            chain: chain
        )
        async let rewardPoints: [String: EraRewardPoints]? = try await performer.performPrefix(
            StakingErasRewardPointsRequest(),
            chain: chain
        )
        async let validatorRewards: [String: StringScaleMapper<BigUInt>]? = try await performer.performPrefix(
            StakingErasValidatorRewardRequest(),
            chain: chain
        )

        return try await SoraEraRewardHistory(
            totalStakeByEra: byEra(totalStake) { $0.value },
            rewardPointsByEra: byEra(rewardPoints) { $0 },
            validatorRewardsByEra: byEra(validatorRewards) { $0.value }
        )
    }

    /// Storage keys are era numbers; entries whose key is not one are left out.
    private static func byEra<Value, Mapped>(
        _ values: [String: Value]?,
        _ transform: (Value) -> Mapped?
    ) -> [EraIndex: Mapped] {
        var result: [EraIndex: Mapped] = [:]
        values?.forEach { key, value in
            if let era = EraIndex(key), let mapped = transform(value) {
                result[era] = mapped
            }
        }
        return result
    }
}
