import SSFModels
import RobinHood
import SSFUtils

enum DeprecatedAccountIssue {
    case controller(issue: ControllerAccountIssue)
    case stash(address: AccountAddress)
}

struct ControllerAccountIssue {
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let address: AccountAddress
}

protocol DeprecatedControllerStashAccountCheckServiceProtocol {
    func checkAccountDeprecations(wallet: MetaAccountModel) async throws -> DeprecatedAccountIssue?
    func checkStashItems() async throws -> [StashItem]
}

final class DeprecatedControllerStashAccountCheckService: DeprecatedControllerStashAccountCheckServiceProtocol {
    private let chainRegistry: ChainRegistryProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationQueue: OperationQueue
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let stashItemRepository: AnyDataProviderRepository<StashItem>

    private var stashItems: [StashItem] = []

    init(
        chainRegistry: ChainRegistryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        stashItemRepository: AnyDataProviderRepository<StashItem>
    ) {
        self.chainRegistry = chainRegistry
        self.chainRepository = chainRepository
        self.storageRequestFactory = storageRequestFactory
        self.operationQueue = operationQueue
        self.walletRepository = walletRepository
        self.stashItemRepository = stashItemRepository
    }

    func checkStashItems() async throws -> [StashItem] {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let strongSelf = self else { return continuation.resume(with: .success([])) }
            let fetchOperation = strongSelf.stashItemRepository.fetchAllOperation(with: RepositoryFetchOptions())
            fetchOperation.completionBlock = {
                do {
                    let stashItem = try fetchOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(stashItem))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
            operationQueue.addOperation(fetchOperation)
        }
    }

    func checkAccountDeprecations(wallet: MetaAccountModel) async throws -> DeprecatedAccountIssue? {
        print("start")
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
        print("define deprecated chains finished")
        var caIssues = try await withThrowingTaskGroup(of: ControllerAccountIssue?.self, body: { group in
            for chainAsset in deprecatedChainAssets {
                group.addTask { [weak self, chainsRuntimesDict] in
                    if let runtime = chainsRuntimesDict[chainAsset.chain] {
                        let controllerAccountId = try? await self?.checkController(
                            for: chainAsset,
                            wallet: wallet,
                            runtime: runtime
                        )
                        if let accountId = controllerAccountId,
                           let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) {
                            return ControllerAccountIssue(
                                chainAsset: chainAsset,
                                wallet: wallet,
                                address: address
                            )
                        }
                        return nil
                    }
                    return nil
                }
            }
            var issues: [ControllerAccountIssue] = []
            for try await issue in group {
                if let issue = issue {
                    issues.append(issue)
                }
            }
            return issues
        })

        var saIssueChainAssetsIds: [ChainAsset: AccountId] = [:]
        for chainAsset in deprecatedChainAssets {
            if let runtime = chainsRuntimesDict[chainAsset.chain] {
                let accountId = try? await checkStash(
                    for: chainAsset,
                    wallet: wallet,
                    runtime: runtime
                )
                let ownAccountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
                if accountId != ownAccountId {
                    if let accountId = accountId,
                       let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) {
                        if let meta = await getStashAccountWallet(chain: chainAsset.chain, address: address) {
                            let caIssue = ControllerAccountIssue(
                                chainAsset: chainAsset,
                                wallet: meta,
                                address: address
                            )
                            caIssues.append(caIssue)
                        } else {
                            saIssueChainAssetsIds[chainAsset] = accountId
                        }
                    }
                }
            }
        }
        if let caIssue = caIssues.first {
            return .controller(issue: caIssue)
        }

        if let saIssue = saIssueChainAssetsIds.keys.first,
           let saIssueId = saIssueChainAssetsIds[saIssue],
           let address = try? AddressFactory.address(for: saIssueId, chain: saIssue.chain) {
            return .stash(address: address)
        }
        return nil
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
        wallet: MetaAccountModel,
        runtime: RuntimeCoderFactoryProtocol
    ) async throws -> AccountId? {
        try await withCheckedThrowingContinuation { continuation in
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
                  let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return continuation.resume(with: .failure(ChainRegistryError.connectionUnavailable))
            }
            let wrapper: CompoundOperationWrapper<[StorageResponse<AccountId>]> =
                storageRequestFactory.queryItems(
                    engine: connection,
                    keyParams: { [accountId] },
                    factory: { runtime },
                    storagePath: .controller
                )

            let controllerOperation = ClosureOperation<AccountId?> {
                try wrapper.targetOperation.extractNoCancellableResultData().first?.value
            }

            wrapper.allOperations.forEach { controllerOperation.addDependency($0) }

            controllerOperation.completionBlock = {
                do {
                    let controllerAccoundId = try controllerOperation.extractNoCancellableResultData()
                    let hasAnotherController = controllerAccoundId != nil && controllerAccoundId != accountId
                    if hasAnotherController {
                        continuation.resume(with: .success(controllerAccoundId))
                    } else {
                        continuation.resume(with: .success(nil))
                    }
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
            let operations: [Operation] = wrapper.allOperations + [controllerOperation]
            operationQueue.addOperations(operations, waitUntilFinished: false)
        }
    }

    private func checkStash(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        runtime: RuntimeCoderFactoryProtocol
    ) async throws -> AccountId? {
        try await withCheckedThrowingContinuation { continuation in
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
                  let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return continuation.resume(with: .failure(ChainRegistryError.connectionUnavailable))
            }
            let wrapper: CompoundOperationWrapper<[StorageResponse<StakingLedger>]> =
                storageRequestFactory.queryItems(
                    engine: connection,
                    keyParams: { [accountId] },
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
            let operations: [Operation] = wrapper.allOperations + [stashOperation]
            operationQueue.addOperations(operations, waitUntilFinished: false)
        }
    }

    private func getStashAccountWallet(chain: ChainModel, address: String) async -> MetaAccountModel? {
        try? await withCheckedThrowingContinuation { continuation in
            fetchMetaAccount(
                chain: chain,
                address: address,
                from: walletRepository,
                operationManager: OperationManagerFacade.sharedManager
            ) { result in
                switch result {
                case let .success(meta):
                    guard let meta = meta else {
                        return continuation.resume(with: .success(nil))
                    }
                    return continuation.resume(with: .success(meta))
                case .failure:
                    return continuation.resume(with: .success(nil))
                }
            }
        }
    }
}

extension DeprecatedControllerStashAccountCheckService: AccountFetching {}
