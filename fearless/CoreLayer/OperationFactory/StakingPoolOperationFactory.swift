import Foundation
import SSFUtils
import RobinHood
import BigInt

protocol StakingPoolOperationFactoryProtocol {
    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]>
    func fetchPoolMetadataOperation(poolId: String) -> CompoundOperationWrapper<String?>
    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?>
    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?>
    func fetchStakingPoolMembers(accountId: AccountId) -> CompoundOperationWrapper<StakingPoolMember?>
    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?>
    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?>
    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?>
    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?>
    func fetchBondedPoolOperation(poolId: String) -> CompoundOperationWrapper<StakingPool?>
    func fetchPoolRewardsOperation(poolId: String) -> CompoundOperationWrapper<StakingPoolRewards?>
    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?>
    func fetchPendingRewards(accountId: AccountId) -> CompoundOperationWrapper<BigUInt?>
}

final class StakingPoolOperationFactory {
    private let chainAsset: ChainAsset
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine

    init(
        chainAsset: ChainAsset,
        storageRequestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine
    ) {
        self.chainAsset = chainAsset
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.engine = engine
    }

    private func createBondedPoolOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        paramsClosure: @escaping () throws -> [String]
    ) -> CompoundOperationWrapper<[StorageResponse<StakingPoolInfo>]> {
        let bondedPoolWrapper: CompoundOperationWrapper<[StorageResponse<StakingPoolInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: paramsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .bondedPools
            )

        bondedPoolWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return bondedPoolWrapper
    }

    private func createBondedPoolsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<StakingPoolInfo>]> {
        let bondedPoolsWrapper: CompoundOperationWrapper<[StorageResponse<StakingPoolInfo>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .bondedPools)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .bondedPools
            )

        bondedPoolsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return bondedPoolsWrapper
    }

    private func createMetadataOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        paramsClosure: @escaping () throws -> [String]
    ) -> CompoundOperationWrapper<[StorageResponse<Data>]> {
        let poolMetadataWrapper: CompoundOperationWrapper<[StorageResponse<Data>]> =
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
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> =
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
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> =
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
    ) -> CompoundOperationWrapper<[StorageResponse<StakingPoolMember>]> {
        let poolMetadataWrapper: CompoundOperationWrapper<[StorageResponse<StakingPoolMember>]> =
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
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
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
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
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
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
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
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let minJoinBondWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolCounterForBondedPools)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolCounterForBondedPools
            )

        minJoinBondWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return minJoinBondWrapper
    }

    private func createStakingPoolRewardsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        paramsClosure: @escaping () throws -> [String]
    ) -> CompoundOperationWrapper<[StorageResponse<StakingPoolRewards>]> {
        let poolMetadataWrapper: CompoundOperationWrapper<[StorageResponse<StakingPoolRewards>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: paramsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolRewards
            )

        poolMetadataWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return poolMetadataWrapper
    }

    private func createLastPoolIdOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let lastPoolIdWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .stakingPoolLastPoolId)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .stakingPoolLastPoolId
            )

        lastPoolIdWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return lastPoolIdWrapper
    }
}

extension StakingPoolOperationFactory: StakingPoolOperationFactoryProtocol {
    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let bondedPoolsOperation = createBondedPoolsOperation(dependingOn: runtimeOperation)

        let mapBondedPoolsOperation = ClosureOperation<[StakingPool]> {
            try bondedPoolsOperation.targetOperation.extractNoCancellableResultData().compactMap { storageResponse in
                guard let stakingPoolInfo = storageResponse.value else {
                    return nil
                }
                let extractor = StorageKeyDataExtractor(storageKey: storageResponse.key)
                let id = try extractor.extractU32Parameter()
                return StakingPool(id: "\(id)", info: stakingPoolInfo, name: "")
            }
        }

        let metadataOperation = createMetadataOperation(dependingOn: runtimeOperation) {
            try mapBondedPoolsOperation.extractNoCancellableResultData().compactMap { $0.id }
        }

        let mapOperation = ClosureOperation<[StakingPool]> {
            let pools = try mapBondedPoolsOperation.extractNoCancellableResultData()
            let result = try metadataOperation.targetOperation.extractNoCancellableResultData()
                .compactMap { storageResponse -> StakingPool? in
                    let name = storageResponse.value?.toUTF8String() ?? ""
                    let extractor = StorageKeyDataExtractor(storageKey: storageResponse.key)
                    let id = try extractor.extractU32Parameter()
                    let idString = "\(id)"

                    guard let pool = pools.first(where: { $0.id.lowercased() == idString.lowercased() }) else {
                        return nil
                    }

                    return pool.byReplacingName(name)
                }

            return result
        }

        mapBondedPoolsOperation.addDependency(bondedPoolsOperation.targetOperation)
        metadataOperation.allOperations.forEach {
            $0.addDependency(mapBondedPoolsOperation)
        }
        mapOperation.addDependency(metadataOperation.targetOperation)

        let dependencies = [runtimeOperation] + bondedPoolsOperation.allOperations + metadataOperation.allOperations + [mapBondedPoolsOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchBondedPoolOperation(poolId: String) -> CompoundOperationWrapper<StakingPool?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let bondedPoolsOperation = createBondedPoolOperation(dependingOn: runtimeOperation) {
            [poolId]
        }

        let mapBondedPoolOperation = ClosureOperation<StakingPool?> {
            guard let storageResponse = try bondedPoolsOperation.targetOperation.extractNoCancellableResultData().first,
                  let stakingPoolInfo = storageResponse.value else {
                return nil
            }

            let extractor = StorageKeyDataExtractor(storageKey: storageResponse.key)
            let id = try extractor.extractU32Parameter()
            return StakingPool(id: "\(id)", info: stakingPoolInfo, name: "")
        }

        let metadataOperation = createMetadataOperation(dependingOn: runtimeOperation) {
            let id = try mapBondedPoolOperation.extractNoCancellableResultData()?.id ?? ""
            return [id]
        }

        let mapOperation = ClosureOperation<StakingPool?> {
            let pool = try mapBondedPoolOperation.extractNoCancellableResultData()
            let storageResponse = try metadataOperation.targetOperation.extractNoCancellableResultData()
            let name = storageResponse.first?.value?.toUTF8String() ?? ""

            return pool?.byReplacingName(name)
        }

        mapBondedPoolOperation.addDependency(bondedPoolsOperation.targetOperation)
        metadataOperation.allOperations.forEach {
            $0.addDependency(mapBondedPoolOperation)
        }
        mapOperation.addDependency(metadataOperation.targetOperation)

        let dependencies = [runtimeOperation] + bondedPoolsOperation.allOperations + metadataOperation.allOperations + [mapBondedPoolOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchPoolMetadataOperation(poolId: String) -> CompoundOperationWrapper<String?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let poolMetadataOperation = createMetadataOperation(dependingOn: runtimeOperation) {
            [poolId]
        }

        let mapOperation = ClosureOperation<String?> {
            try poolMetadataOperation.targetOperation.extractNoCancellableResultData().compactMap { $0.value?.toUTF8String() }.first
        }

        mapOperation.addDependency(poolMetadataOperation.targetOperation)

        let dependencies = [runtimeOperation] + poolMetadataOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let minJoinBondOperation = createMinJoinBondOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<BigUInt?> {
            try minJoinBondOperation.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        mapOperation.addDependency(minJoinBondOperation.targetOperation)

        let dependencies = [runtimeOperation] + minJoinBondOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let minCreateBondOperation = createMinCreateBondOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<BigUInt?> {
            try minCreateBondOperation.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        mapOperation.addDependency(minCreateBondOperation.targetOperation)

        let dependencies = [runtimeOperation] + minCreateBondOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchStakingPoolMembers(accountId: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let stakingPoolMembersOperation = createStakingPoolMembersOperation(dependingOn: runtimeOperation) {
            [accountId]
        }

        let mapOperation = ClosureOperation<StakingPoolMember?> {
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
            try maxStakingPoolsCountOperation.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        mapOperation.addDependency(maxStakingPoolsCountOperation.targetOperation)

        let dependencies = [runtimeOperation] + maxStakingPoolsCountOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let maxPoolMembersOperation = createMaxPoolMembersOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<UInt32?> {
            try maxPoolMembersOperation.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        mapOperation.addDependency(maxPoolMembersOperation.targetOperation)

        let dependencies = [runtimeOperation] + maxPoolMembersOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let counterForBondedPoolsOperation = createCounterForBondedPoolsOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<UInt32?> {
            try counterForBondedPoolsOperation.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        mapOperation.addDependency(counterForBondedPoolsOperation.targetOperation)

        let dependencies = [runtimeOperation] + counterForBondedPoolsOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let maxPoolMembersPerPoolOperation = createMaxPoolMembersPerPoolOperation(dependingOn: runtimeOperation)
        let mapOperation = ClosureOperation<UInt32?> {
            try maxPoolMembersPerPoolOperation.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        mapOperation.addDependency(maxPoolMembersPerPoolOperation.targetOperation)

        let dependencies = [runtimeOperation] + maxPoolMembersPerPoolOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchPoolRewardsOperation(poolId: String) -> CompoundOperationWrapper<StakingPoolRewards?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let stakingPoolMembersOperation = createStakingPoolRewardsOperation(dependingOn: runtimeOperation) {
            [poolId]
        }

        let mapOperation = ClosureOperation<StakingPoolRewards?> {
            try stakingPoolMembersOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(stakingPoolMembersOperation.targetOperation)

        let dependencies = [runtimeOperation] + stakingPoolMembersOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let lastPoolIdOperation = createLastPoolIdOperation(dependingOn: runtimeOperation)

        let mapOperation = ClosureOperation<UInt32?> {
            try lastPoolIdOperation.targetOperation.extractNoCancellableResultData().first?.value?.value
        }

        mapOperation.addDependency(lastPoolIdOperation.targetOperation)

        let dependencies = [runtimeOperation] + lastPoolIdOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchPendingRewards(accountId: AccountId) -> CompoundOperationWrapper<BigUInt?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let params = [RuntimeCallPath.nominationPoolsPendingRewards.rawValue, accountId.toHex(includePrefix: true)]

        let infoOperation = JSONRPCListOperation<String?>(
            engine: engine,
            method: RPCMethod.stateCall,
            parameters: params
        )

        let mappingOperation = ClosureOperation<BigUInt?> {
            guard let result = try infoOperation.extractNoCancellableResultData() else {
                return BigUInt.zero
            }

            let data = try Data(hexString: result)
            let decoder = try runtimeOperation.extractNoCancellableResultData().createDecoder(from: data)

            guard let claimableString = try decoder.readU128().stringValue else {
                return BigUInt.zero
            }

            let claimable = BigUInt(claimableString)

            return claimable
        }

        mappingOperation.addDependency(infoOperation)
        mappingOperation.addDependency(runtimeOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [infoOperation, runtimeOperation]
        )

        return wrapper
    }
}
