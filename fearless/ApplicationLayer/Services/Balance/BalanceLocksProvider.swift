import Foundation
import SSFModels
import SSFUtils
import RobinHood

enum BalanceLocksProviderError: Error {
    case unknownChainAssetType
}

protocol BalanceLocksProviderProtocol {
    func fetchBalanceLocks(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> [LockProtocol]?
}

final class BalanceLocksProvider {
    private let operationManager: OperationManagerProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol

    init(
        operationManager: OperationManagerProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.operationManager = operationManager
        self.storageRequestFactory = storageRequestFactory
        self.chainRegistry = chainRegistry
    }

    private func fetchBalanceLocks(
        wallet _: MetaAccountModel,
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) async throws -> [LockProtocol]? {
        try await withCheckedThrowingContinuation { continuation in
            if let accountId = try? "0xb6886973c891bf20892bfe376d58c89e42f42163a47816c2b064ac7e78528f25".toAccountId() {
//            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
                let balanceLocksOperation: CompoundOperationWrapper<[LockProtocol]?>

                let tokensPalletAvailable = runtimeService.snapshot?.metadata.modules.first(where: { $0.name.lowercased() == "tokens" }) != nil
                if tokensPalletAvailable {
                    balanceLocksOperation = createTokensLocksFetchOperation(
                        for: accountId,
                        chainAsset: chainAsset,
                        runtimeService: runtimeService,
                        connection: connection
                    )
                } else {
                    balanceLocksOperation = createBalanceLocksFetchOperation(
                        for: accountId,
                        chainAsset: chainAsset,
                        runtimeService: runtimeService,
                        connection: connection
                    )
                }

                balanceLocksOperation.targetOperation.completionBlock = {
                    do {
                        let balanceLocks = try balanceLocksOperation.targetOperation.extractNoCancellableResultData()
                        return continuation.resume(with: .success(balanceLocks))
                    } catch {
                        return continuation.resume(with: .failure(error))
                    }
                }

                operationManager.enqueue(
                    operations: balanceLocksOperation.allOperations,
                    in: .transient
                )
            }
        }
    }

    private func createTokensLocksFetchOperation(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[LockProtocol]?> {
        guard let currencyId = chainAsset.currencyId else {
            return CompoundOperationWrapper.createWithError(BalanceLocksProviderError.unknownChainAssetType)
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<TokenLocks>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: currencyId)]] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .tokensLocks
        )

        let mapOperation = ClosureOperation<[LockProtocol]?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createBalanceLocksFetchOperation(
        for accountId: AccountId,
        chainAsset _: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[LockProtocol]?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<BalanceLocks>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .balanceLocks
        )

        let mapOperation = ClosureOperation<[LockProtocol]?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}

extension BalanceLocksProvider: BalanceLocksProviderProtocol {
    func fetchBalanceLocks(for chainAsset: ChainAsset, wallet: MetaAccountModel) async throws -> [LockProtocol]? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        return try await fetchBalanceLocks(
            wallet: wallet,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            connection: connection
        )
    }
}
