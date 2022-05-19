import Foundation
import FearlessUtils
import RobinHood

final class ParachainValidatorOperationFactory {
    let asset: AssetModel
    let chain: ChainModel
    let eraValidatorService: EraValidatorServiceProtocol
    let rewardService: RewardCalculatorServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let engine: JSONRPCEngine

    init(
        asset: AssetModel,
        chain: ChainModel,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.asset = asset
        self.chain = chain
        self.eraValidatorService = eraValidatorService
        self.rewardService = rewardService
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.engine = engine
        self.identityOperationFactory = identityOperationFactory
    }

    func createStorageKeyOperation(from storagePath: StorageCodingPath) -> ClosureOperation<Data> {
        ClosureOperation<Data> {
            try StorageKeyFactory().key(from: storagePath)
        }
    }

    func createCandidatePoolOperation(dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) -> CompoundOperationWrapper<[StorageResponse<[ParachainStakingCandidate]>]> {
        guard let candidatePoolKey = try? StorageKeyFactory().key(from: .candidatePool) else {
            return CompoundOperationWrapper(targetOperation: ClosureOperation { [] })
        }

        let candidatePoolWrapper: CompoundOperationWrapper<[StorageResponse<[ParachainStakingCandidate]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [candidatePoolKey] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .candidatePool
            )

        candidatePoolWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return candidatePoolWrapper
    }

    func createSelectedCandidatesOperation(dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) -> CompoundOperationWrapper<[StorageResponse<[AccountId]>]> {
        guard let selectedCandidatesKey = try? StorageKeyFactory().key(from: .selectedCandidates) else {
            return CompoundOperationWrapper(targetOperation: ClosureOperation { [] })
        }

        let selectedCandidatesWrapper: CompoundOperationWrapper<[StorageResponse<[AccountId]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [selectedCandidatesKey] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .selectedCandidates
            )

        selectedCandidatesWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return selectedCandidatesWrapper
    }
}

extension ParachainValidatorOperationFactory {
    // swiftlint:disable function_body_length
    func allElectedOperation() -> CompoundOperationWrapper<[ParachainStakingCandidate]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let candidatePoolOperation = createCandidatePoolOperation(dependingOn: runtimeOperation)
        let selectedCandidatesOperation = createSelectedCandidatesOperation(dependingOn: runtimeOperation)

        let mergeOperation = ClosureOperation<[ParachainStakingCandidate]?> {
            let candidatePool = try candidatePoolOperation.targetOperation.extractNoCancellableResultData().first?.value
            let selectedCandidatesIds = try selectedCandidatesOperation.targetOperation.extractNoCancellableResultData().first?.value

            let selectedCandidates = candidatePool?.filter { selectedCandidatesIds?.contains($0.owner) == true }
            return selectedCandidates
        }

        mergeOperation.addDependency(candidatePoolOperation.targetOperation)
        mergeOperation.addDependency(selectedCandidatesOperation.targetOperation)

        let dependencies = [runtimeOperation] + candidatePoolOperation.allOperations
            + selectedCandidatesOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    // swiftlint:disable function_body_length
    func allSelectedOperation(
        by _: Nomination,
        nominatorAddress _: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let candidatePoolOperation = createCandidatePoolOperation(dependingOn: runtimeOperation)
        let selectedCandidatesOperation = createSelectedCandidatesOperation(dependingOn: runtimeOperation)

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let candidatePool = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()
            let selectedCandidates = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()

            return candidatePool.compactMap { $0.value?.first?.owner }.compactMap { SelectedValidatorInfo(address: "$0") }
        }

        mergeOperation.addDependency(candidatePoolOperation.targetOperation)
        mergeOperation.addDependency(selectedCandidatesOperation.targetOperation)

        let dependencies = candidatePoolOperation.allOperations + selectedCandidatesOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func activeValidatorsOperation(
        for _: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let candidatePoolOperation = createCandidatePoolOperation(dependingOn: runtimeOperation)
        let selectedCandidatesOperation = createSelectedCandidatesOperation(dependingOn: runtimeOperation)

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let candidatePool = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()
            let selectedCandidates = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()

            return candidatePool.compactMap { $0.value?.first?.owner }.compactMap { SelectedValidatorInfo(address: "$0") }
        }

        mergeOperation.addDependency(candidatePoolOperation.targetOperation)
        mergeOperation.addDependency(selectedCandidatesOperation.targetOperation)

        let dependencies = candidatePoolOperation.allOperations + selectedCandidatesOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func pendingValidatorsOperation(
        for _: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let candidatePoolOperation = createCandidatePoolOperation(dependingOn: runtimeOperation)
        let selectedCandidatesOperation = createSelectedCandidatesOperation(dependingOn: runtimeOperation)

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let candidatePool = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()
            let selectedCandidates = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()

            return candidatePool.compactMap { $0.value?.first?.owner }.compactMap { SelectedValidatorInfo(address: "$0") }
        }

        mergeOperation.addDependency(candidatePoolOperation.targetOperation)
        mergeOperation.addDependency(selectedCandidatesOperation.targetOperation)

        let dependencies = candidatePoolOperation.allOperations + selectedCandidatesOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    // swiftlint:disable function_body_length
    func wannabeValidatorsOperation(
        for _: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let candidatePoolOperation = createCandidatePoolOperation(dependingOn: runtimeOperation)
        let selectedCandidatesOperation = createSelectedCandidatesOperation(dependingOn: runtimeOperation)

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let candidatePool = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()
            let selectedCandidates = try candidatePoolOperation.targetOperation.extractNoCancellableResultData()

            return candidatePool.compactMap { $0.value?.first?.owner }.compactMap { SelectedValidatorInfo(address: "$0") }
        }

        mergeOperation.addDependency(candidatePoolOperation.targetOperation)
        mergeOperation.addDependency(selectedCandidatesOperation.targetOperation)

        let dependencies = candidatePoolOperation.allOperations + selectedCandidatesOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
