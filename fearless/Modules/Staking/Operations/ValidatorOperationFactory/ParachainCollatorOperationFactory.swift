import Foundation
import FearlessUtils
import RobinHood

final class ParachainCollatorOperationFactory {
    let asset: AssetModel
    let chain: ChainModel
    let storageRequestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let engine: JSONRPCEngine

    init(
        asset: AssetModel,
        chain: ChainModel,
        storageRequestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.asset = asset
        self.chain = chain
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

    func createTopDelegationsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingDelegations]> {
        let topDelegationsWrapper: CompoundOperationWrapper<[StorageResponse<ParachainStakingDelegations>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: accountIdsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .topDelegations
            )

        topDelegationsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mergeOperation = ClosureOperation<[AccountAddress: ParachainStakingDelegations]> { [weak self] in
            guard let strongSelf = self else {
                return [:]
            }

            let topDelegations = try topDelegationsWrapper.targetOperation.extractNoCancellableResultData()

            var metadataByAddress: [AccountAddress: ParachainStakingDelegations] = [:]
            try topDelegations.compactMap {
                let accountId = $0.key.getAccountIdFromKey(accountIdLenght: strongSelf.chain.accountIdLenght)
                let address = try AddressFactory.address(for: accountId, chainFormat: strongSelf.chain.chainFormat)
                if let metadata = $0.value {
                    metadataByAddress[address] = metadata
                }
            }

            return metadataByAddress
        }

        mergeOperation.addDependency(topDelegationsWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: topDelegationsWrapper.allOperations)
    }

    func createCollatorInfoOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingCandidateMetadata]> {
        let candidateInfoWrapper: CompoundOperationWrapper<[StorageResponse<ParachainStakingCandidateMetadata>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: accountIdsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .candidateInfo
            )

        candidateInfoWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mergeOperation = ClosureOperation<[AccountAddress: ParachainStakingCandidateMetadata]> { [weak self] in
            guard let strongSelf = self else {
                return [:]
            }

            let candidateInfos = try candidateInfoWrapper.targetOperation.extractNoCancellableResultData()

            var metadataByAddress: [AccountAddress: ParachainStakingCandidateMetadata] = [:]
            try candidateInfos.compactMap {
                let accountId = $0.key.getAccountIdFromKey(accountIdLenght: strongSelf.chain.accountIdLenght)
                let address = try AddressFactory.address(for: accountId, chainFormat: strongSelf.chain.chainFormat)
                if let metadata = $0.value {
                    metadataByAddress[address] = metadata
                }
            }

            return metadataByAddress
        }

        mergeOperation.addDependency(candidateInfoWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: candidateInfoWrapper.allOperations)
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

extension ParachainCollatorOperationFactory {
    func allElectedOperation() -> CompoundOperationWrapper<[ParachainStakingCandidateInfo]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let candidatePoolOperation = createCandidatePoolOperation(dependingOn: runtimeOperation)
        let selectedCandidatesOperation = createSelectedCandidatesOperation(dependingOn: runtimeOperation)

        let accountIdsClosure: () throws -> [AccountId] = {
            try selectedCandidatesOperation.targetOperation.extractNoCancellableResultData().first?.value ?? []
        }

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: accountIdsClosure,
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        let infoWrapper = createCollatorInfoOperation(dependingOn: runtimeOperation, accountIdsClosure: accountIdsClosure)

        identityWrapper.allOperations.forEach { $0.addDependency(selectedCandidatesOperation.targetOperation) }
        infoWrapper.allOperations.forEach { $0.addDependency(selectedCandidatesOperation.targetOperation) }

        let mergeOperation = ClosureOperation<[ParachainStakingCandidateInfo]?> {
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let infos = try infoWrapper.targetOperation.extractNoCancellableResultData()

            let candidatePool = try candidatePoolOperation.targetOperation.extractNoCancellableResultData().first?.value
            let selectedCandidatesIds = try selectedCandidatesOperation.targetOperation.extractNoCancellableResultData().first?.value

            let selectedCandidates: [ParachainStakingCandidateInfo]? = try candidatePool?
                .filter { selectedCandidatesIds?.contains($0.owner) == true }
                .compactMap { [weak self] in
                    guard let strongSelf = self else {
                        return nil
                    }

                    let address = try AddressFactory.address(
                        for: $0.owner,
                        chainFormat: strongSelf.chain.chainFormat
                    )
                    return ParachainStakingCandidateInfo(
                        address: address,
                        owner: $0.owner,
                        amount: $0.amount,
                        metadata: infos[address],
                        identity: identities[address]
                    )
                }

            return selectedCandidates
        }

        mergeOperation.addDependency(candidatePoolOperation.targetOperation)
        mergeOperation.addDependency(selectedCandidatesOperation.targetOperation)
        mergeOperation.addDependency(infoWrapper.targetOperation)
        mergeOperation.addDependency(identityWrapper.targetOperation)

        let dependencies = [runtimeOperation] + candidatePoolOperation.allOperations
            + selectedCandidatesOperation.allOperations + identityWrapper.allOperations + infoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func collatorInfoOperation(accountId: AccountId) -> CompoundOperationWrapper<ParachainStakingCandidateMetadata?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let candidateInfoOperation = createCollatorInfoOperation(dependingOn: runtimeOperation) {
            [accountId]
        }

        let mapOperation = ClosureOperation<ParachainStakingCandidateMetadata?> {
            try candidateInfoOperation.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(candidateInfoOperation.targetOperation)

        let dependencies = [runtimeOperation] + candidateInfoOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func collatorTopDelegations(accountIdsClosure: @escaping () throws -> [AccountId]) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingDelegations]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let topDelegationsWrapper = createTopDelegationsOperation(
            dependingOn: runtimeOperation,
            accountIdsClosure: accountIdsClosure
        )

        let mapOperation = ClosureOperation<[AccountAddress: ParachainStakingDelegations]?> {
            try topDelegationsWrapper.targetOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(topDelegationsWrapper.targetOperation)

        let dependencies = [runtimeOperation] + topDelegationsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
