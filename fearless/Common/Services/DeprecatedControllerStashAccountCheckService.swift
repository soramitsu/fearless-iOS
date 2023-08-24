import SSFModels
import RobinHood
import SSFUtils

enum DeprecatedAccountIssue {
    case controller(chainAsset: ChainAsset)
    case stash(address: AccountAddress)
}

protocol DeprecatedControllerStashAccountCheckServiceProtocol {
    func checkAccountDeprecations(wallet: MetaAccountModel) async throws -> DeprecatedAccountIssue?
}

final class DeprecatedControllerStashAccountCheckService: DeprecatedControllerStashAccountCheckServiceProtocol {
    private let chainRegistry: ChainRegistryProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.chainRepository = chainRepository
        self.storageRequestFactory = storageRequestFactory
        self.operationQueue = operationQueue
    }

    private func getPossibleChainAssets() async throws -> [ChainAsset] {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let strongSelf = self else { return continuation.resume(with: .success([])) }
            let chainsOperation = strongSelf.chainRepository.fetchAllOperation(with: RepositoryFetchOptions())
            chainsOperation.completionBlock = {
                do {
                    let chains = try chainsOperation.extractNoCancellableResultData()
                    let chainAssets = chains.map { $0.chainAssets.filter { $0.stakingType?.isRelaychain == true } }.reduce([], +)
                    continuation.resume(with: .success(chainAssets))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
            operationQueue.addOperation(chainsOperation)
        }
    }

    private func getRuntime(for chain: ChainModel) async throws -> RuntimeCoderFactoryProtocol {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let strongSelf = self else { return continuation.resume(with: .failure(ChainRegistryError.runtimeMetadaUnavailable)) }
            guard let runtimeService = strongSelf.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
                return continuation.resume(with: .failure(ChainRegistryError.runtimeMetadaUnavailable))
            }
            let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
            runtimeOperation.completionBlock = {
                do {
                    let runtime = try runtimeOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(runtime))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
            operationQueue.addOperation(runtimeOperation)
        }
    }

    private func checkController(
        for chainAsset: ChainAsset,
        runtime: RuntimeCoderFactoryProtocol
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
                return continuation.resume(with: .failure(ChainRegistryError.connectionUnavailable))
            }
            let wrapper: CompoundOperationWrapper<[StorageResponse<AccountId>]> =
                storageRequestFactory.queryItemsByPrefix(
                    engine: connection,
                    keys: { [try StorageKeyFactory().key(from: .controller)] },
                    factory: { runtime },
                    storagePath: .controller
                )

            let controllerOperation = ClosureOperation<AccountId?> {
                try wrapper.targetOperation.extractNoCancellableResultData().first?.value
            }

            wrapper.allOperations.forEach { controllerOperation.addDependency($0) }

            controllerOperation.completionBlock = {
                do {
                    _ = try controllerOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(true))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
            operationQueue.addOperation(controllerOperation)
        }
    }

    private func checkStash(
        for chainAsset: ChainAsset,
        runtime: RuntimeCoderFactoryProtocol
    ) async throws -> AccountId? {
        try await withCheckedThrowingContinuation { continuation in
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
                return continuation.resume(with: .failure(ChainRegistryError.connectionUnavailable))
            }
            let wrapper: CompoundOperationWrapper<[StorageResponse<StakingLedger>]> =
                storageRequestFactory.queryItemsByPrefix(
                    engine: connection,
                    keys: { [try StorageKeyFactory().key(from: .stakingLedger)] },
                    factory: { runtime },
                    storagePath: .stakingLedger
                )

            let stashOperation = ClosureOperation<StakingLedger?> {
                try wrapper.targetOperation.extractNoCancellableResultData().first?.value
            }

            wrapper.allOperations.forEach { stashOperation.addDependency($0) }

            stashOperation.completionBlock = {
                do {
                    let stakingLedger = try stashOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(stakingLedger?.stash))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
            operationQueue.addOperation(stashOperation)
        }
    }

    func checkAccountDeprecations(wallet _: MetaAccountModel) async throws -> DeprecatedAccountIssue? {
        guard let possibleChainAssets = try? await getPossibleChainAssets() else { return nil }
        let chains = Array(Set(possibleChainAssets.compactMap { $0.chain }))
        var chainsRuntimesDict: [ChainModel: RuntimeCoderFactoryProtocol] = [:]
        for chain in chains {
            do {
                let runtime = try await getRuntime(for: chain)
                chainsRuntimesDict[chain] = runtime
            } catch {
                throw RuntimeProviderError.providerUnavailable
            }
        }

        let deprecatedChainAssets: [ChainAsset] = possibleChainAssets.filter { chainAsset in
            (try? chainsRuntimesDict[chainAsset.chain]?.metadata.checkArgument(
                moduleName: "Staking",
                callName: "set_controller",
                argumentName: "controller"
            )) == false
        }

        var caIssueChainAssets: [ChainAsset] = []
        for chainAsset in deprecatedChainAssets {
            if let runtime = chainsRuntimesDict[chainAsset.chain] {
                let hasController = try? await checkController(
                    for: chainAsset,
                    runtime: runtime
                )
                if hasController == true {
                    caIssueChainAssets.append(chainAsset)
                }
            }
        }

        var saIssueChainAssets: [ChainAsset] = []
        var saIssueChainAssetsIds: [ChainAsset: AccountId] = [:]
        for chainAsset in deprecatedChainAssets {
            if let runtime = chainsRuntimesDict[chainAsset.chain] {
                let accountId = try? await checkStash(
                    for: chainAsset,
                    runtime: runtime
                )
                if let accountId = accountId {
                    saIssueChainAssets.append(chainAsset)
                    saIssueChainAssetsIds[chainAsset] = accountId
                }
            }
        }

        if let caIssue = caIssueChainAssets.first {
            return .controller(chainAsset: caIssue)
        }

        if let saIssue = saIssueChainAssets.first,
           let saIssueId = saIssueChainAssetsIds[saIssue],
           let address = try? AddressFactory.address(for: saIssueId, chain: saIssue.chain) {
            return .stash(address: address)
        }

        return nil
    }
}
