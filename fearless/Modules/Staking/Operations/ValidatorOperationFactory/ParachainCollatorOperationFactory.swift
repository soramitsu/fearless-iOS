import Foundation
import FearlessUtils
import RobinHood
import BigInt
import CommonWallet

final class ParachainCollatorOperationFactory {
    private let asset: AssetModel
    private let chain: ChainModel
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let identityOperationFactory: IdentityOperationFactoryProtocol
    private let subqueryOperationFactory: SubqueryRewardOperationFactoryProtocol
    private let engine: JSONRPCEngine

    init(
        asset: AssetModel,
        chain: ChainModel,
        storageRequestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        subqueryOperationFactory: SubqueryRewardOperationFactoryProtocol
    ) {
        self.asset = asset
        self.chain = chain
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.engine = engine
        self.identityOperationFactory = identityOperationFactory
        self.subqueryOperationFactory = subqueryOperationFactory
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
            try topDelegations.forEach {
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

    func createBottomDelegationsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingDelegations]> {
        let bottomDelegationsWrapper: CompoundOperationWrapper<[StorageResponse<ParachainStakingDelegations>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: accountIdsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .bottomDelegations
            )

        bottomDelegationsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mergeOperation = ClosureOperation<[AccountAddress: ParachainStakingDelegations]> { [weak self] in
            guard let strongSelf = self else {
                return [:]
            }

            let bottomDelegations = try bottomDelegationsWrapper.targetOperation.extractNoCancellableResultData()

            var metadataByAddress: [AccountAddress: ParachainStakingDelegations] = [:]
            try bottomDelegations.forEach {
                let accountId = $0.key.getAccountIdFromKey(accountIdLenght: strongSelf.chain.accountIdLenght)
                let address = try AddressFactory.address(for: accountId, chainFormat: strongSelf.chain.chainFormat)
                if let metadata = $0.value {
                    metadataByAddress[address] = metadata
                }
            }

            return metadataByAddress
        }

        mergeOperation.addDependency(bottomDelegationsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: bottomDelegationsWrapper.allOperations
        )
    }

    func createAtStakeOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        params: @escaping () throws -> [[NMapKeyParamProtocol]]
    ) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingCollatorSnapshot]> {
        let atStakeWrapper: CompoundOperationWrapper<[StorageResponse<ParachainStakingCollatorSnapshot>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: params,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .atStake
            )

        atStakeWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mergeOperation = ClosureOperation<[AccountAddress: ParachainStakingCollatorSnapshot]> { [weak self] in
            guard let strongSelf = self else {
                return [:]
            }

            let topDelegations = try atStakeWrapper.targetOperation.extractNoCancellableResultData()

            var metadataByAddress: [AccountAddress: ParachainStakingCollatorSnapshot] = [:]
            try topDelegations.forEach {
                let accountId = $0.key.getAccountIdFromKey(accountIdLenght: strongSelf.chain.accountIdLenght)
                let address = try AddressFactory.address(for: accountId, chainFormat: strongSelf.chain.chainFormat)
                if let metadata = $0.value {
                    metadataByAddress[address] = metadata
                }
            }

            return metadataByAddress
        }

        mergeOperation.addDependency(atStakeWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: atStakeWrapper.allOperations)
    }

    func createDelegatorStateOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingDelegatorState]> {
        let topDelegationsWrapper: CompoundOperationWrapper<[StorageResponse<ParachainStakingDelegatorState>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: accountIdsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .delegatorState
            )

        topDelegationsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mergeOperation = ClosureOperation<[AccountAddress: ParachainStakingDelegatorState]> { [weak self] in
            guard let strongSelf = self else {
                return [:]
            }

            let topDelegations = try topDelegationsWrapper.targetOperation.extractNoCancellableResultData()

            var metadataByAddress: [AccountAddress: ParachainStakingDelegatorState] = [:]
            try topDelegations.forEach {
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
            try candidateInfos.forEach {
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
        let candidatePoolWrapper: CompoundOperationWrapper<[StorageResponse<[ParachainStakingCandidate]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .candidatePool)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .candidatePool
            )

        candidatePoolWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return candidatePoolWrapper
    }

    func createSelectedCandidatesOperation(dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) -> CompoundOperationWrapper<[StorageResponse<[AccountId]>]> {
        let selectedCandidatesWrapper: CompoundOperationWrapper<[StorageResponse<[AccountId]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .selectedCandidates)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .selectedCandidates
            )

        selectedCandidatesWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return selectedCandidatesWrapper
    }

    func createDelegationScheduledRequestsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: [ParachainStakingScheduledRequest]]> {
        let delegationScheduledRequestsWrapper: CompoundOperationWrapper<[StorageResponse<[ParachainStakingScheduledRequest]>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: accountIdsClosure,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .delegationScheduledRequests
            )

        delegationScheduledRequestsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mergeOperation = ClosureOperation<[AccountAddress: [ParachainStakingScheduledRequest]]> { [weak self] in
            guard let strongSelf = self else {
                return [:]
            }

            let requestsInfo = try delegationScheduledRequestsWrapper.targetOperation.extractNoCancellableResultData()

            var requestsByAddress: [AccountAddress: [ParachainStakingScheduledRequest]] = [:]
            try requestsInfo.forEach {
                let accountId = $0.key.getAccountIdFromKey(accountIdLenght: strongSelf.chain.accountIdLenght)
                let address = try AddressFactory.address(for: accountId, chainFormat: strongSelf.chain.chainFormat)
                if let requests = $0.value {
                    requestsByAddress[address] = requests
                }
            }

            return requestsByAddress
        }

        mergeOperation.addDependency(delegationScheduledRequestsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: delegationScheduledRequestsWrapper.allOperations
        )
    }

    func createRoundOperation(dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) -> CompoundOperationWrapper<[StorageResponse<ParachainStakingRoundInfo>]> {
        let candidatePoolWrapper: CompoundOperationWrapper<[StorageResponse<ParachainStakingRoundInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .round)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .round
            )

        candidatePoolWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return candidatePoolWrapper
    }

    func createCurrentBlockOperation(dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) -> CompoundOperationWrapper<[StorageResponse<String>]> {
        let candidatePoolWrapper: CompoundOperationWrapper<[StorageResponse<String>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .currentBlock)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .currentBlock
            )

        candidatePoolWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return candidatePoolWrapper
    }

    func createCommissionOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<String>]> {
        let candidatePoolWrapper: CompoundOperationWrapper<[StorageResponse<String>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .collatorCommission)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .collatorCommission
            )

        candidatePoolWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return candidatePoolWrapper
    }

    func createStakedOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        roundOperation: CompoundOperationWrapper<[StorageResponse<ParachainStakingRoundInfo>]>
    ) -> CompoundOperationWrapper<[StorageResponse<String>]> {
        let params: (() throws -> [String]) = { ["\(try roundOperation.targetOperation.extractNoCancellableResultData().first?.value?.current ?? 0)"] }

        let candidatePoolWrapper: CompoundOperationWrapper<[StorageResponse<String>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: params,
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .staked
            )

        candidatePoolWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return candidatePoolWrapper
    }
}

extension ParachainCollatorOperationFactory {
    func candidateInfos(for candidateIdsOperation: CompoundOperationWrapper<[AccountId]>) -> CompoundOperationWrapper<[ParachainStakingCandidateInfo]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let accountIdsClosure: () throws -> [AccountId] = {
            try candidateIdsOperation.targetOperation.extractNoCancellableResultData()
        }

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: accountIdsClosure,
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        let infoWrapper = createCollatorInfoOperation(
            dependingOn: runtimeOperation,
            accountIdsClosure: accountIdsClosure
        )

        let roundOperation = subqueryOperationFactory.createLastRoundOperation()
        let aprOperation = subqueryOperationFactory.createAprOperation(
            for: accountIdsClosure,
            dependingOn: roundOperation
        )

        identityWrapper.allOperations.forEach { $0.addDependency(candidateIdsOperation.targetOperation) }
        infoWrapper.allOperations.forEach { $0.addDependency(candidateIdsOperation.targetOperation) }
        aprOperation.addDependency(candidateIdsOperation.targetOperation)
        aprOperation.addDependency(roundOperation)

        let mergeOperation = ClosureOperation<[ParachainStakingCandidateInfo]?> {
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let infos = try infoWrapper.targetOperation.extractNoCancellableResultData()
            let collatorsApr = try? aprOperation.extractNoCancellableResultData()

            let candidateInfos: [ParachainStakingCandidateInfo]? = try infos
                .keys
                .compactMap { [weak self] key in
                    guard let strongSelf = self else {
                        return nil
                    }

                    let metadata = infos[key]
                    let address = key
                    let owner = try key.toAccountId()

                    let subqueryData = collatorsApr?.collatorRounds.nodes.first(where: { $0.collatorId.lowercased() == address.lowercased() })
                    let amountDecimal = Decimal.fromSubstrateAmount(metadata?.totalCounted ?? BigUInt.zero, precision: Int16(strongSelf.asset.precision)) ?? 0

                    return ParachainStakingCandidateInfo(
                        address: address,
                        owner: owner,
                        amount: AmountDecimal(value: amountDecimal),
                        metadata: infos[address],
                        identity: identities[address],
                        subqueryData: subqueryData
                    )
                }

            return candidateInfos
        }

        mergeOperation.addDependency(roundOperation)
        mergeOperation.addDependency(aprOperation)
        mergeOperation.addDependency(candidateIdsOperation.targetOperation)
        mergeOperation.addDependency(infoWrapper.targetOperation)
        mergeOperation.addDependency(identityWrapper.targetOperation)

        var dependencies: [Operation] = []
        dependencies.append(runtimeOperation)
        dependencies.append(contentsOf: candidateIdsOperation.allOperations)
        dependencies.append(contentsOf: identityWrapper.allOperations)
        dependencies.append(contentsOf: infoWrapper.allOperations)
        dependencies.append(aprOperation)
        dependencies.append(roundOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func allElectedOperation() -> CompoundOperationWrapper<[ParachainStakingCandidateInfo]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let candidatePoolOperation = createCandidatePoolOperation(dependingOn: runtimeOperation)
        let selectedCandidatesOperation = createSelectedCandidatesOperation(dependingOn: runtimeOperation)

        let accountIdsClosure: () throws -> [AccountId] = {
            try selectedCandidatesOperation.targetOperation.extractNoCancellableResultData().first?.value ?? []
        }

        let roundIdOperation = subqueryOperationFactory.createLastRoundOperation()
        let aprOperation = subqueryOperationFactory.createAprOperation(for: accountIdsClosure, dependingOn: roundIdOperation)

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: accountIdsClosure,
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )

        let infoWrapper = createCollatorInfoOperation(dependingOn: runtimeOperation, accountIdsClosure: accountIdsClosure)

        identityWrapper.allOperations.forEach { $0.addDependency(selectedCandidatesOperation.targetOperation) }
        infoWrapper.allOperations.forEach { $0.addDependency(selectedCandidatesOperation.targetOperation) }
        aprOperation.addDependency(selectedCandidatesOperation.targetOperation)
        aprOperation.addDependency(roundIdOperation)

        let mergeOperation = ClosureOperation<[ParachainStakingCandidateInfo]?> {
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let infos = try infoWrapper.targetOperation.extractNoCancellableResultData()
            let collatorsApr = try? aprOperation.extractNoCancellableResultData()

            let candidatePool = try candidatePoolOperation.targetOperation.extractNoCancellableResultData().first?.value
            let selectedCandidatesIds = try selectedCandidatesOperation.targetOperation.extractNoCancellableResultData().first?.value

            let selectedCandidates: [ParachainStakingCandidateInfo]? = try candidatePool?
                .filter { selectedCandidatesIds?.contains($0.owner) == true }
                .compactMap { [weak self] collator in
                    guard let strongSelf = self else {
                        return nil
                    }

                    let address = try AddressFactory.address(
                        for: collator.owner,
                        chainFormat: strongSelf.chain.chainFormat
                    )

                    let subqueryData = collatorsApr?.collatorRounds.nodes.first(where: { $0.collatorId.lowercased() == address.lowercased() && $0.apr != 0 })

                    return ParachainStakingCandidateInfo(
                        address: address,
                        owner: collator.owner,
                        amount: collator.amount,
                        metadata: infos[address],
                        identity: identities[address],
                        subqueryData: subqueryData
                    )
                }

            return selectedCandidates
        }

        mergeOperation.addDependency(roundIdOperation)
        mergeOperation.addDependency(aprOperation)
        mergeOperation.addDependency(candidatePoolOperation.targetOperation)
        mergeOperation.addDependency(selectedCandidatesOperation.targetOperation)
        mergeOperation.addDependency(infoWrapper.targetOperation)
        mergeOperation.addDependency(identityWrapper.targetOperation)

        var dependencies: [Operation] = []
        dependencies.append(runtimeOperation)
        dependencies.append(contentsOf: candidatePoolOperation.allOperations)
        dependencies.append(contentsOf: selectedCandidatesOperation.allOperations)
        dependencies.append(contentsOf: identityWrapper.allOperations)
        dependencies.append(contentsOf: infoWrapper.allOperations)
        dependencies.append(aprOperation)
        dependencies.append(roundIdOperation)

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

    func collatorBottomDelegations(accountIdsClosure: @escaping () throws -> [AccountId]) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingDelegations]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let topDelegationsWrapper = createBottomDelegationsOperation(
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

    func collatorAtStake(
        collatorAccountId: AccountId
    ) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingCollatorSnapshot]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let roundOperation = createRoundOperation(dependingOn: runtimeOperation)

        let paramsClosure: () throws -> [[NMapKeyParamProtocol]] = {
            let round = try roundOperation.targetOperation.extractNoCancellableResultData().first?.value?.current ?? 0

            return [[NMapKeyParam(value: round)], [NMapKeyParam(value: collatorAccountId)]]
        }

        let atStakeWrapper = createAtStakeOperation(
            dependingOn: runtimeOperation,
            params: paramsClosure
        )

        atStakeWrapper.addDependency(wrapper: roundOperation)

        let mapOperation = ClosureOperation<[AccountAddress: ParachainStakingCollatorSnapshot]?> {
            try atStakeWrapper.targetOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(atStakeWrapper.targetOperation)
        mapOperation.addDependency(roundOperation.targetOperation)

        let dependencies = [runtimeOperation] + atStakeWrapper.allOperations + roundOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func delegatorState(
        accountIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: ParachainStakingDelegatorState]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let delegatorStateWrapper = createDelegatorStateOperation(
            dependingOn: runtimeOperation,
            accountIdsClosure: accountIdsClosure
        )

        let mapOperation = ClosureOperation<[AccountAddress: ParachainStakingDelegatorState]?> {
            try delegatorStateWrapper.targetOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(delegatorStateWrapper.targetOperation)

        let dependencies = [runtimeOperation] + delegatorStateWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func delegationScheduledRequests(accountIdsClosure: @escaping () throws -> [AccountId]) -> CompoundOperationWrapper<[AccountAddress: [ParachainStakingScheduledRequest]]?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let delegatorStateWrapper = createDelegationScheduledRequestsOperation(
            dependingOn: runtimeOperation,
            accountIdsClosure: accountIdsClosure
        )

        let mapOperation = ClosureOperation<[AccountAddress: [ParachainStakingScheduledRequest]]?> {
            try delegatorStateWrapper.targetOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(delegatorStateWrapper.targetOperation)

        let dependencies = [runtimeOperation] + delegatorStateWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func round() -> CompoundOperationWrapper<ParachainStakingRoundInfo?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let roundWrapper = createRoundOperation(dependingOn: runtimeOperation)

        let mapOperation = ClosureOperation<ParachainStakingRoundInfo?> {
            try roundWrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(roundWrapper.targetOperation)

        let dependencies = [runtimeOperation] + roundWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func commission() -> CompoundOperationWrapper<String?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let commissionWrapper = createCommissionOperation(dependingOn: runtimeOperation)

        let mapOperation = ClosureOperation<String?> {
            try commissionWrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(commissionWrapper.targetOperation)

        let dependencies = [runtimeOperation] + commissionWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func staked() -> CompoundOperationWrapper<String?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let roundOperation = createRoundOperation(dependingOn: runtimeOperation)

        let stakedWrapper = createStakedOperation(dependingOn: runtimeOperation, roundOperation: roundOperation)

        stakedWrapper.allOperations.forEach {
            $0.addDependency(roundOperation.targetOperation)
        }

        let mapOperation = ClosureOperation<String?> {
            try stakedWrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(stakedWrapper.targetOperation)

        let dependencies = [runtimeOperation] + roundOperation.allOperations + stakedWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func currentBlock() -> CompoundOperationWrapper<String?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let blockWrapper = createCurrentBlockOperation(dependingOn: runtimeOperation)

        let mapOperation = ClosureOperation<String?> {
            try blockWrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        mapOperation.addDependency(blockWrapper.targetOperation)

        let dependencies = [runtimeOperation] + blockWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
