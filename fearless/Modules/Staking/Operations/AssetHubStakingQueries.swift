import Foundation
import SSFUtils
import SSFRuntimeCodingService
import BigInt

struct AssetHubStakingQueries {
    let scanner: AssetHubPagedStorage

    func plain<Value: Decodable>(_ path: StorageCodingPath) async throws -> Value {
        let values: [StorageResponse<Value>] = try await scanner.storage.queryItems(
            engine: scanner.engine, keys: [try StorageKeyFactory().key(from: path)],
            factory: scanner.runtime, storagePath: path, at: scanner.block
        )
        guard let value = values.first?.value else { throw EraValidatorServiceError.unexpectedInfo }
        return value
    }

    func era<Value: Decodable>(_ path: StorageCodingPath, era: EraIndex) async throws -> Value {
        let values: [StorageResponse<Value>] = try await scanner.storage.queryItems(
            engine: scanner.engine, keyParams: [StringScaleMapper(value: era)],
            factory: scanner.runtime, storagePath: path, at: scanner.block
        )
        guard let value = values.first?.value else { throw EraValidatorServiceError.unexpectedInfo }
        return value
    }

    func validator<Value: Decodable>(_ path: StorageCodingPath, era: EraIndex, account: AccountId) async throws -> Value {
        let values: [StorageResponse<Value>] = try await scanner.storage.queryItems(
            engine: scanner.engine,
            keyParams: [[[NMapKeyParam(value: StringScaleMapper(value: era))], [NMapKeyParam(value: account)]]],
            factory: scanner.runtime, storagePath: path, at: scanner.block
        )
        guard let value = values.first?.value else { throw EraValidatorServiceError.unexpectedInfo }
        return value
    }

    func validatorIncentive(era: EraIndex, account: AccountId, points: UInt32) async throws -> BigUInt {
        let budget: StringScaleMapper<BigUInt> = try await self.era(.validatorIncentiveBudget, era: era)
        guard budget.value > 0, points > 0 else { return 0 }
        let weights: [StorageResponse<StringScaleMapper<BigUInt>>] = try await scanner.storage.queryItems(
            engine: scanner.engine,
            keyParams: [[[NMapKeyParam(value: StringScaleMapper(value: era))], [NMapKeyParam(value: account)]]],
            factory: scanner.runtime, storagePath: .validatorIncentiveWeight, at: scanner.block
        )
        guard let weight = weights.first?.value?.value, weight > 0 else { return 0 }
        let hasCutoff = scanner.runtime.metadata.getStorageMetadata(for: .weightedPointsFormulaStartEra) != nil
        if hasCutoff {
            let cutoffValues: [StorageResponse<StringScaleMapper<EraIndex>>] = try await scanner.storage.queryItems(
                engine: scanner.engine, keys: [try StorageKeyFactory().key(from: .weightedPointsFormulaStartEra)],
                factory: scanner.runtime, storagePath: .weightedPointsFormulaStartEra, at: scanner.block
            )
            guard cutoffValues.count == 1 else { throw EraValidatorServiceError.unexpectedInfo }
            if (cutoffValues.first?.value?.value).map({ era >= $0 }) ?? true {
                let denominator: StringScaleMapper<BigUInt> = try await self.era(.sumWeightedPoints, era: era)
                return try AssetHubRewardMath.fraction(weight * BigUInt(points), of: denominator.value, times: budget.value)
            }
        }
        let denominator: StringScaleMapper<BigUInt> = try await self.era(.sumValidatorIncentiveWeight, era: era)
        return try AssetHubRewardMath.fraction(weight, of: denominator.value, times: budget.value)
    }
}
