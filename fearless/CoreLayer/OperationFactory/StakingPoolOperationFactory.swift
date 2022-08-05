import Foundation
import FearlessUtils
import RobinHood
import BigInt

protocol StakingPoolOperationFactoryProtocol {
    func fetchBondedPoolsOperation(era: EraIndex) -> CompoundOperationWrapper<[StakingPool]?>
    func fetchPoolMetadataOperation(poolId: UInt32) -> CompoundOperationWrapper<[Data]?>
    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?>
    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?>
    func fetchStakingPoolMembers(accountId: AccountId) -> CompoundOperationWrapper<[StakingPoolMember]?>
    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?>
    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?>
    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?>
    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?>
}

final class StakingPoolOperationFactory {
    private let chainAsset: ChainAsset
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let identityOperationFactory: IdentityOperationFactoryProtocol
    private let subqueryOperationFactory: SubqueryRewardOperationFactoryProtocol
    private let engine: JSONRPCEngine

    init(
        chainAsset: ChainAsset,
        storageRequestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        subqueryOperationFactory: SubqueryRewardOperationFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.engine = engine
        self.identityOperationFactory = identityOperationFactory
        self.subqueryOperationFactory = subqueryOperationFactory
    }

    private func createBondedPoolsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        paramsClosure: @escaping () throws -> [EraIndex]
    ) -> CompoundOperationWrapper<[StorageResponse<[StakingPool]>]> {
        let topDelegationsWrapper: CompoundOperationWrapper<[StorageResponse<[StakingPool]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: paramsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .bondedPools
            )

        topDelegationsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return topDelegationsWrapper
    }

    private func createMetadataOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        paramsClosure: @escaping () throws -> [UInt32]
    ) -> CompoundOperationWrapper<[StorageResponse<[Data]>]> {
        let poolMetadataWrapper: CompoundOperationWrapper<[StorageResponse<[Data]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: paramsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMetadata
            )

        poolMetadataWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return poolMetadataWrapper
    }

    private func createMinJoinBondOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<BigUInt>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<BigUInt>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolMinJoinBond)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMinJoinBond
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }

    private func createMinCreateBondOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<BigUInt>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<BigUInt>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolMinCreateBond)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMinCreateBond
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }

    private func createPoolMembersOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<BigUInt>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<BigUInt>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolMembers)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMembers
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }

    private func createStakingPoolMembersOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        paramsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[StorageResponse<[StakingPoolMember]>]> {
        let poolMetadataWrapper: CompoundOperationWrapper<[StorageResponse<[StakingPoolMember]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: paramsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMembers
            )

        poolMetadataWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return poolMetadataWrapper
    }

    private func createMaxPoolMembersOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<UInt32>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<UInt32>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolMaxPoolMembers)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMaxPoolMembers
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }

    private func createMaxPoolsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<UInt32>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<UInt32>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolMaxPools)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMaxPools
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }

    private func createMaxPoolMembersPerPoolOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<UInt32>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<UInt32>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolMaxPoolMembersPerPool)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolMaxPoolMembersPerPool
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }

    private func createCounterForBondedPoolsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<UInt32>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<UInt32>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolCounterForBondedPools)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolCounterForBondedPools
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }
}

extension StakingPoolOperationFactory: StakingPoolOperationFactoryProtocol {
    func fetchBondedPoolsOperation(era: EraIndex) -> CompoundOperationWrapper<[StakingPool]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let bondedPoolsOperation = createBondedPoolsOperation(dependingOn: runtimeOperation) {
            [era]
        }

        let mapOperation = ClosureOperation<[StakingPool]?> {
            try bondedPoolsOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(bondedPoolsOperation.targetOperation)

        let dependencies = [runtimeOperation] + bondedPoolsOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchPoolMetadataOperation(poolId: UInt32) -> CompoundOperationWrapper<[Data]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let poolMetadataOperation = createMetadataOperation(dependingOn: runtimeOperation) {
            [poolId]
        }

        let mapOperation = ClosureOperation<[Data]?> {
            try poolMetadataOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(poolMetadataOperation.targetOperation)

        let dependencies = [runtimeOperation] + poolMetadataOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let minJoinBondOperation = createMinJoinBondOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<BigUInt?> {
            try minJoinBondOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(minJoinBondOperation.targetOperation)

        let dependencies = [runtimeOperation] + minJoinBondOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let minCreateBondOperation = createMinJoinBondOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<BigUInt?> {
            try minCreateBondOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(minCreateBondOperation.targetOperation)

        let dependencies = [runtimeOperation] + minCreateBondOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchStakingPoolMembers(accountId: AccountId) -> CompoundOperationWrapper<[StakingPoolMember]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let stakingPoolMembersOperation = createStakingPoolMembersOperation(dependingOn: runtimeOperation) {
            [accountId]
        }

        let mapOperation = ClosureOperation<[StakingPoolMember]?> {
            try stakingPoolMembersOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(stakingPoolMembersOperation.targetOperation)

        let dependencies = [runtimeOperation] + stakingPoolMembersOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let maxStakingPoolsCountOperation = createMaxPoolsOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<UInt32?> {
            try maxStakingPoolsCountOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(maxStakingPoolsCountOperation.targetOperation)

        let dependencies = [runtimeOperation] + maxStakingPoolsCountOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let maxPoolMembersOperation = createMaxPoolMembersOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<UInt32?> {
            try maxPoolMembersOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(maxPoolMembersOperation.targetOperation)

        let dependencies = [runtimeOperation] + maxPoolMembersOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let counterForBondedPoolsOperation = createCounterForBondedPoolsOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<UInt32?> {
            try counterForBondedPoolsOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(counterForBondedPoolsOperation.targetOperation)

        let dependencies = [runtimeOperation] + counterForBondedPoolsOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let maxPoolMembersPerPoolOperation = createMaxPoolMembersPerPoolOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<UInt32?> {
            try maxPoolMembersPerPoolOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(maxPoolMembersPerPoolOperation.targetOperation)

        let dependencies = [runtimeOperation] + maxPoolMembersPerPoolOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
