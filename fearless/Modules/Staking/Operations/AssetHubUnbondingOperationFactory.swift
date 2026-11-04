import Foundation
import RobinHood
import SSFUtils
import SSFRuntimeCodingService

struct AssetHubUnbondingOperationFactory {
    let storage: StorageRequestFactoryProtocol
    let duration: StakingDurationOperationFactoryProtocol

    static func unbondingEras(
        activeEra: EraIndex,
        lastValidatorEra: EraIndex?,
        nominatorsSlashable: Bool,
        bondingDuration: UInt32,
        fastDuration: UInt32
    ) throws -> UInt32 {
        guard fastDuration <= bondingDuration else { throw EraValidatorServiceError.unexpectedInfo }
        if let last = lastValidatorEra, activeEra < last || activeEra - last < bondingDuration {
            return bondingDuration
        }
        return nominatorsSlashable ? bondingDuration : fastDuration
    }

    func create(
        accountId: AccountId,
        runtime: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<StakingDuration> {
        let coder = runtime.fetchCoderFactoryOperation()
        let timing = duration.createDurationOperation(from: runtime)
        let bonding: PrimitiveConstantOperation<UInt32> = constant(.lockUpPeriod, coder: coder)
        let fast: PrimitiveConstantOperation<UInt32> = constant(.nominatorFastUnbondDuration, coder: coder)
        let era: CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> = storage.queryItems(
            engine: connection, keys: { [try StorageKeyFactory().key(from: .activeEra)] },
            factory: { try coder.extractNoCancellableResultData() }, storagePath: .activeEra
        )
        let slashable: CompoundOperationWrapper<[StorageResponse<Bool>]> = storage.queryItems(
            engine: connection, keys: { [try StorageKeyFactory().key(from: .areNominatorsSlashable)] },
            factory: { try coder.extractNoCancellableResultData() }, storagePath: .areNominatorsSlashable
        )
        let last: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<EraIndex>>]> = storage.queryItems(
            engine: connection, keyParams: { [accountId] },
            factory: { try coder.extractNoCancellableResultData() }, storagePath: .lastValidatorEra
        )
        let queries = era.allOperations + slashable.allOperations + last.allOperations + [bonding, fast]
        queries.forEach { $0.addDependency(coder) }
        let result = ClosureOperation<StakingDuration> {
            guard let active = try era.targetOperation.extractNoCancellableResultData().first?.value?.index,
                  let canSlash = try slashable.targetOperation.extractNoCancellableResultData().first?.value else {
                throw EraValidatorServiceError.unexpectedInfo
            }
            let periods = try Self.unbondingEras(
                activeEra: active, lastValidatorEra: last.targetOperation.extractNoCancellableResultData().first?.value?.value,
                nominatorsSlashable: canSlash, bondingDuration: bonding.extractNoCancellableResultData(),
                fastDuration: fast.extractNoCancellableResultData()
            )
            let value = try timing.targetOperation.extractNoCancellableResultData()
            return StakingDuration(session: value.session, era: value.era, unlocking: value.era * TimeInterval(periods))
        }
        let dependencies = queries + timing.allOperations + [coder]
        dependencies.forEach { result.addDependency($0) }
        return CompoundOperationWrapper(targetOperation: result, dependencies: dependencies)
    }

    func applying(
        duration: CompoundOperationWrapper<StakingDuration>,
        to network: CompoundOperationWrapper<NetworkStakingInfo>
    ) -> CompoundOperationWrapper<NetworkStakingInfo> {
        let result = ClosureOperation<NetworkStakingInfo> {
            let info = try network.targetOperation.extractNoCancellableResultData()
            let timing = try duration.targetOperation.extractNoCancellableResultData()
            guard let relay = info.relaychainInfo, timing.era > 0, timing.era.isFinite,
                  timing.unlocking.isFinite, timing.unlocking > 0,
                  let periods = UInt32(exactly: timing.unlocking / timing.era), periods > 0 else {
                throw EraValidatorServiceError.unexpectedInfo
            }
            return .relaychain(
                baseInfo: BaseStakingInfo(
                    lockUpPeriod: periods,
                    minimalBalance: info.baseInfo.minimalBalance,
                    minStakeAmongActiveNominators: info.baseInfo.minStakeAmongActiveNominators
                ),
                relaychainInfo: RelaychainStakingInfo(
                    stakingDuration: timing,
                    totalStake: relay.totalStake,
                    activeNominatorsCount: relay.activeNominatorsCount
                )
            )
        }
        let dependencies = duration.allOperations + network.allOperations
        dependencies.forEach { result.addDependency($0) }
        return CompoundOperationWrapper(targetOperation: result, dependencies: dependencies)
    }

    private func constant(_ path: ConstantCodingPath, coder: BaseOperation<RuntimeCoderFactoryProtocol>) -> PrimitiveConstantOperation<UInt32> {
        let operation = PrimitiveConstantOperation<UInt32>(path: path)
        operation.configurationBlock = {
            do { operation.codingFactory = try coder.extractNoCancellableResultData() }
            catch { operation.result = .failure(error) }
        }
        return operation
    }
}
