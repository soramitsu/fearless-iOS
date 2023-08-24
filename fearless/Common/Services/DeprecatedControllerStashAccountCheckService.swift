import SSFModels
import RobinHood
import SSFUtils

enum DeprecatedAccountIssue {
    case controller(chainAsset: ChainAsset)
    case stash(address: AccountAddress)
}

final class DeprecatedControllerStashAccountCheckService {
    private let chainRegistry: ChainRegistryProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let wallet: MetaAccountModel
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        storageRequestFactory: StorageRequestFactoryProtocol,
        wallet: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.chainRepository = chainRepository
        self.storageRequestFactory = storageRequestFactory
        self.wallet = wallet
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
        runtime: RuntimeCoderFactoryProtocol,
        completionBlock: @escaping (Bool) -> Void
    ) {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return
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
            if let _ = try? controllerOperation.extractNoCancellableResultData() {
                completionBlock(true)
            }
        }
        operationQueue.addOperation(controllerOperation)
    }

    private func checkStash(
        for chainAsset: ChainAsset,
        runtime: RuntimeCoderFactoryProtocol,
        completionBlock: @escaping (AccountId?) -> Void
    ) {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return
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
            if let stakingLedger = try? stashOperation.extractNoCancellableResultData() {
                completionBlock(stakingLedger.stash)
            }
        }
        operationQueue.addOperation(stashOperation)
    }

    func checkAccountDeprecations() async throws -> DeprecatedAccountIssue? {
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
            )) == true
        }

        // bond call - check controller account exist -> if exist - show alert
        var caIssueChainAssets: [ChainAsset] = []
        deprecatedChainAssets.forEach { [weak self] chainAsset in
            if let runtime = chainsRuntimesDict[chainAsset.chain] {
                self?.checkController(
                    for: chainAsset,
                    runtime: runtime,
                    completionBlock: { hasController in
                        if hasController {
                            caIssueChainAssets.append(chainAsset)
                        }
                    }
                )
            }
        }

        // ledger call - check stash account exist -> if exist - show alert
        var saIssueChainAssets: [ChainAsset] = []
        var saIssueChainAssetsIds: [ChainAsset: AccountId] = [:]
        deprecatedChainAssets.forEach { [weak self] chainAsset in
            if let runtime = chainsRuntimesDict[chainAsset.chain] {
                self?.checkStash(
                    for: chainAsset,
                    runtime: runtime,
                    completionBlock: { accountId in
                        if let accountId = accountId {
                            saIssueChainAssets.append(chainAsset)
                            saIssueChainAssetsIds[chainAsset] = accountId
                        }
                    }
                )
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
