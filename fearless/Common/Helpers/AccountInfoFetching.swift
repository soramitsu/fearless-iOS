import Foundation
import RobinHood

protocol AccountInfoFetchingProtocol {
    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    )

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    )
}

final class AccountInfoFetching: AccountInfoFetchingProtocol {
    private let accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue

    init(
        accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountInfoRepository = accountInfoRepository
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        let keys: [String] = chainAssets.compactMap { chainAsset in
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
                  let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
                      chainAsset.storagePath,
                      chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
                  ) else {
                return nil
            }

            return localKey
        }

        let fetchOperation = accountInfoRepository.fetchOperation(by: keys, options: RepositoryFetchOptions())
        let mapChainAssetsWithKeysOperation = ClosureOperation<[ChainAssetKey: ChainAsset]> {
            let chainAssetsByKeys = chainAssets.reduce(into: [ChainAssetKey: ChainAsset]()) { map, chainAsset in
                guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
                      let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
                          chainAsset.storagePath,
                          chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
                      ) else {
                    return
                }

                map[localKey] = chainAsset
            }

            return chainAssetsByKeys
        }

        let transformToDecodingOperationsOperation = ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
            let rawResult = try fetchOperation.extractNoCancellableResultData()
            let chainAssetsByKeys = try mapChainAssetsWithKeysOperation.extractNoCancellableResultData()
            let zeroBalanceChainAssetKeys = rawResult.compactMap { $0.identifier }.diff(from: keys)
            let zeroBalanceChainAssets = chainAssets.filter { chainAsset in
                guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
                      let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
                          chainAsset.storagePath,
                          chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
                      ) else {
                    return false
                }

                return zeroBalanceChainAssetKeys.contains(localKey)
            }

            let zeroBalanceOperations: [ClosureOperation<[ChainAsset: AccountInfo?]>] = zeroBalanceChainAssets.compactMap { chainAsset in
                ClosureOperation { [chainAsset: nil] }
            }

            let operations: [ClosureOperation<[ChainAsset: AccountInfo?]>] = rawResult.compactMap { accountInfoStorageWrapper in
                let identifier = accountInfoStorageWrapper.identifier
                guard let chainAsset = chainAssetsByKeys[accountInfoStorageWrapper.identifier] else {
                    return ClosureOperation { [:] }
                }

                switch chainAsset.chainAssetType {
                case .normal:
                    guard let decodingOperation: StorageDecodingOperation<AccountInfo?> = self.createDecodingOperation(
                        for: accountInfoStorageWrapper.data,
                        chainAsset: chainAsset,
                        storagePath: .account
                    ) else {
                        return ClosureOperation { [chainAsset: nil] }
                    }

                    let operation = self.createNormalMappingOperation(
                        chainAsset: chainAsset,
                        dependingOn: decodingOperation
                    )

                    return operation
                case
                    .ormlChain,
                    .ormlAsset,
                    .foreignAsset,
                    .stableAssetPoolToken,
                    .liquidCrowdloan,
                    .vToken,
                    .vsToken,
                    .stable,
                    .soraAsset:
                    guard let decodingOperation: StorageDecodingOperation<OrmlAccountInfo?> = self.createDecodingOperation(
                        for: accountInfoStorageWrapper.data,
                        chainAsset: chainAsset,
                        storagePath: .tokens
                    ) else {
                        return ClosureOperation { [chainAsset: nil] }
                    }

                    let operation = self.createOrmlMappingOperation(
                        chainAsset: chainAsset,
                        dependingOn: decodingOperation
                    )

                    return operation
                case .equilibrium:
                    guard let decodingOperation: StorageDecodingOperation<EquilibriumAccountInfo?> = self.createDecodingOperation(
                        for: accountInfoStorageWrapper.data,
                        chainAsset: chainAsset,
                        storagePath: chainAsset.storagePath
                    ) else {
                        return ClosureOperation { [chainAsset: nil] }
                    }

                    let operation = self.createEquilibriumMappingOperation(
                        chainAsset: chainAsset,
                        dependingOn: decodingOperation
                    )

                    return operation
                }
            }

            return operations + zeroBalanceOperations
        }

        let mappingOperation = ClosureOperation { [weak self] in
            let decodingOperations = try transformToDecodingOperationsOperation.extractNoCancellableResultData()
            let decodingDependencies = decodingOperations.compactMap { $0.dependencies }.reduce([], +)
            let decodingSubdependencies = decodingDependencies.compactMap { $0.dependencies }.reduce([], +)

            let finishOperation = ClosureOperation {
                let accountInfos = decodingOperations.compactMap { try? $0.extractNoCancellableResultData() }.flatMap { $0 }
                let accountInfoByChainAsset = Dictionary(accountInfos, uniquingKeysWith: { _, last in last })

                completionBlock(accountInfoByChainAsset)
            }

            decodingOperations.forEach { finishOperation.addDependency($0) }
            decodingDependencies.forEach { finishOperation.addDependency($0) }
            decodingSubdependencies.forEach { finishOperation.addDependency($0) }

            self?.operationQueue.addOperations([finishOperation] + decodingOperations + decodingDependencies + decodingSubdependencies, waitUntilFinished: true)
        }

        transformToDecodingOperationsOperation.addDependency(fetchOperation)
        transformToDecodingOperationsOperation.addDependency(mapChainAssetsWithKeysOperation)
        mappingOperation.addDependency(transformToDecodingOperationsOperation)

        operationQueue.addOperations([fetchOperation, mapChainAssetsWithKeysOperation, transformToDecodingOperationsOperation, mappingOperation], waitUntilFinished: true)
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
            chainAsset.storagePath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        ) else {
            completionBlock(chainAsset, nil)
            return
        }

        let operation = accountInfoRepository.fetchOperation(by: localKey, options: RepositoryFetchOptions())
        operation.completionBlock = { [weak self] in
            let result = operation.result
            switch result {
            case let .success(item):
                guard let item = item else {
                    completionBlock(chainAsset, nil)
                    return
                }
                switch chainAsset.chainAssetType {
                case .normal:
                    self?.handleAccountInfo(
                        chainAsset: chainAsset,
                        item: item,
                        completionBlock: completionBlock
                    )
                case
                    .ormlChain,
                    .ormlAsset,
                    .foreignAsset,
                    .stableAssetPoolToken,
                    .liquidCrowdloan,
                    .vToken,
                    .vsToken,
                    .stable,
                    .soraAsset:
                    self?.handleOrmlAccountInfo(
                        chainAsset: chainAsset,
                        accountId: accountId,
                        item: item,
                        completionBlock: completionBlock
                    )
                case .equilibrium:
                    self?.handleEquilibrium(
                        chainAsset: chainAsset,
                        accountId: accountId,
                        item: item,
                        completionBlock: completionBlock
                    )
                }
            default:
                completionBlock(chainAsset, nil)
            }
        }
        operationQueue.addOperation(operation)
    }
}

private extension AccountInfoFetching {
    func createNormalMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<AccountInfo?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation {
            let accountInfo = try decodingOperation.extractNoCancellableResultData()
            return [chainAsset: accountInfo]
        }

        operation.addDependency(decodingOperation)

        return operation
    }

    func createOrmlMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<OrmlAccountInfo?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation {
            let ormlAccountInfo = try decodingOperation.extractNoCancellableResultData()
            let accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
            return [chainAsset: accountInfo]
        }

        operation.addDependency(decodingOperation)

        return operation
    }

    func createEquilibriumMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<EquilibriumAccountInfo?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation<[ChainAsset: AccountInfo?]> {
            let equilibriumAccountInfo = try decodingOperation.extractNoCancellableResultData()
            var accountInfo: AccountInfo?

            switch equilibriumAccountInfo?.data {
            case let .v0data(info):
                guard let currencyId = chainAsset.asset.currencyId else {
                    return [chainAsset: nil]
                }

                let map = info.mapBalances()
                let equilibriumFree = map[currencyId]
                accountInfo = AccountInfo(equilibriumFree: equilibriumFree)
            case .none:
                break
            }

            return [chainAsset: accountInfo]
        }

        operation.addDependency(decodingOperation)

        return operation
    }

    func createDecodingOperation<T: Decodable>(
        for data: Data,
        chainAsset: ChainAsset,
        storagePath: StorageCodingPath
    ) -> StorageDecodingOperation<T?>? {
        guard
            let runtimeCodingService = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            return nil
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<T?>(
            path: storagePath,
            data: data
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        return decodingOperation
    }

    func handleOrmlAccountInfo(
        chainAsset: ChainAsset,
        accountId _: AccountId,
        item: AccountInfoStorageWrapper,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard let decodingOperation: StorageDecodingOperation<OrmlAccountInfo?> = createDecodingOperation(
            for: item.data,
            chainAsset: chainAsset,
            storagePath: .tokens
        ) else {
            completionBlock(chainAsset, nil)
            return
        }

        decodingOperation.completionBlock = {
            DispatchQueue.main.async {
                guard let result = decodingOperation.result else {
                    completionBlock(chainAsset, nil)
                    return
                }

                switch result {
                case let .success(ormlAccountInfo):
                    let accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
                    completionBlock(chainAsset, accountInfo)
                case .failure:
                    completionBlock(chainAsset, nil)
                }
            }
        }
        operationQueue.addOperations([decodingOperation] + decodingOperation.dependencies, waitUntilFinished: false)
    }

    func handleAccountInfo(
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard let decodingOperation: StorageDecodingOperation<AccountInfo?> = createDecodingOperation(
            for: item.data,
            chainAsset: chainAsset,
            storagePath: .account
        ) else {
            completionBlock(chainAsset, nil)
            return
        }

        decodingOperation.completionBlock = {
            DispatchQueue.main.async {
                guard let result = decodingOperation.result else {
                    completionBlock(chainAsset, nil)
                    return
                }
                switch result {
                case let .success(accountInfo):
                    completionBlock(chainAsset, accountInfo)
                case .failure:
                    completionBlock(chainAsset, nil)
                }
            }
        }
        operationQueue.addOperations([decodingOperation] + decodingOperation.dependencies, waitUntilFinished: false)
    }

    func handleEquilibrium(
        chainAsset: ChainAsset,
        accountId: AccountId,
        item: AccountInfoStorageWrapper,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard let decodingOperation: StorageDecodingOperation<EquilibriumAccountInfo?> = createDecodingOperation(
            for: item.data,
            chainAsset: chainAsset,
            storagePath: chainAsset.storagePath
        ) else {
            completionBlock(chainAsset, nil)
            return
        }

        decodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let result = decodingOperation.result else {
                    completionBlock(chainAsset, nil)
                    return
                }
                self?.handleEquilibrium(result: result, chainAsset: chainAsset, accountId: accountId, completionBlock: completionBlock)
            }
        }
        operationQueue.addOperations([decodingOperation] + decodingOperation.dependencies, waitUntilFinished: false)
    }

    private func handleEquilibrium(
        result: Result<EquilibriumAccountInfo?, Error>,
        chainAsset: ChainAsset,
        accountId _: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        switch result {
        case let .success(equilibriumAccountInfo):
            switch equilibriumAccountInfo?.data {
            case let .v0data(info):
                let map = info.mapBalances()
                chainAsset.chain.chainAssets.forEach { chainAsset in
                    guard let currencyId = chainAsset.asset.currencyId else {
                        return
                    }
                    let equilibriumFree = map[currencyId]
                    let accountInfo = AccountInfo(equilibriumFree: equilibriumFree)
                    completionBlock(chainAsset, accountInfo)
                }
            case .none:
                completionBlock(chainAsset, nil)
            }
        case .failure:
            completionBlock(chainAsset, nil)
        }
    }
}
