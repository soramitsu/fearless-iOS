import Foundation
import SSFModels
import RobinHood

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
        let createAccountInfoOperationsOperation = prepareAccountInfoOperationsOperation(
            chainAssets: chainAssets,
            wallet: wallet
        )

        let dependencies = createAccountInfoOperationsOperation.dependencies

        let executeOperation = ClosureOperation { [weak self] in
            let accountInfoOperations = try createAccountInfoOperationsOperation.extractNoCancellableResultData()
            let accountInfoDependencies = accountInfoOperations.compactMap { $0.dependencies }.reduce([], +)
            let accountInfoSubdependencies = accountInfoDependencies.compactMap { $0.dependencies }.reduce([], +)

            let finishOperation = ClosureOperation {
                let accountInfos = accountInfoOperations.compactMap { try? $0.extractNoCancellableResultData() }.flatMap { $0 }
                let accountInfoByChainAsset = Dictionary(accountInfos, uniquingKeysWith: { _, last in last })

                completionBlock(accountInfoByChainAsset)
            }

            accountInfoOperations.forEach { finishOperation.addDependency($0) }
            accountInfoDependencies.forEach { finishOperation.addDependency($0) }
            accountInfoSubdependencies.forEach { finishOperation.addDependency($0) }

            self?.operationQueue.addOperations([finishOperation] + accountInfoOperations + accountInfoDependencies + accountInfoSubdependencies, waitUntilFinished: false)
        }

        executeOperation.addDependency(createAccountInfoOperationsOperation)
        createAccountInfoOperationsOperation.dependencies.forEach { executeOperation.addDependency($0) }

        operationQueue.addOperations(dependencies + [createAccountInfoOperationsOperation, executeOperation], waitUntilFinished: false)
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
                if chainAsset.chain.isEthereum {
                    self?.handleEthereumAccountInfo(
                        chainAsset: chainAsset,
                        item: item, completionBlock:
                        completionBlock
                    )
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
                    .assetId,
                    .token2:
                    self?.handleOrmlAccountInfo(
                        chainAsset: chainAsset,
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
                case .assets:
                    self?.handleAssetAccount(
                        chainAsset: chainAsset,
                        item: item,
                        completionBlock: completionBlock
                    )
                case .soraAsset:
                    if chainAsset.isUtility {
                        self?.handleAccountInfo(
                            chainAsset: chainAsset,
                            item: item,
                            completionBlock: completionBlock
                        )
                    } else {
                        self?.handleOrmlAccountInfo(
                            chainAsset: chainAsset,
                            item: item,
                            completionBlock: completionBlock
                        )
                    }
                case .none:
                    break
                }
            default:
                completionBlock(chainAsset, nil)
            }
        }
        operationQueue.addOperation(operation)
    }
}

private extension AccountInfoFetching {
    private func prepareAccountInfoOperationsOperation(
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) -> ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
        let keys = generateStorageKeys(
            for: chainAssets,
            wallet: wallet
        )

        let mapChainAssetsWithKeysOperation = createMapChainAssetsWithKeysOperation(
            chainAssets: chainAssets,
            wallet: wallet
        )

        let fetchOperation = accountInfoRepository.fetchOperation(
            by: keys,
            options: RepositoryFetchOptions()
        )

        let zeroBalanceOperations = createZeroBalanceAccountInfoOperations(
            dependingOn: fetchOperation,
            keys: keys,
            chainAssets: chainAssets,
            wallet: wallet
        )

        zeroBalanceOperations.addDependency(fetchOperation)

        let positiveBalanceOperations = ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
            let rawResult = try fetchOperation.extractNoCancellableResultData()
            let chainAssetsByKeys = try mapChainAssetsWithKeysOperation.extractNoCancellableResultData()

            let operations: [ClosureOperation<[ChainAsset: AccountInfo?]>] = rawResult.compactMap { [weak self] accountInfoStorageWrapper in
                self?.createDecodeOperation(
                    accountInfoStorageWrapper: accountInfoStorageWrapper,
                    chainAssetsByKeys: chainAssetsByKeys
                )
            }

            return operations
        }

        positiveBalanceOperations.addDependency(fetchOperation)
        positiveBalanceOperations.addDependency(mapChainAssetsWithKeysOperation)

        let uniteOperation = ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
            let zeroOperations = try zeroBalanceOperations.extractNoCancellableResultData()
            let positiveOperations = try positiveBalanceOperations.extractNoCancellableResultData()

            return zeroOperations + positiveOperations
        }

        uniteOperation.addDependency(mapChainAssetsWithKeysOperation)
        uniteOperation.addDependency(fetchOperation)
        uniteOperation.addDependency(zeroBalanceOperations)
        uniteOperation.addDependency(positiveBalanceOperations)

        return uniteOperation
    }

    private func createDecodeOperation(
        accountInfoStorageWrapper: AccountInfoStorageWrapper,
        chainAssetsByKeys: [ChainAssetKey: ChainAsset]
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        guard let chainAsset = chainAssetsByKeys[accountInfoStorageWrapper.identifier] else {
            return ClosureOperation { [:] }
        }

        if chainAsset.chain.isEthereum {
            return ClosureOperation {
                let accountInfo = try JSONDecoder().decode(AccountInfo?.self, from: accountInfoStorageWrapper.data)

                return [chainAsset: accountInfo]
            }
        }
        switch chainAsset.chainAssetType {
        case .none:
            return ClosureOperation { [chainAsset: nil] }
        case .normal:
            guard let decodingOperation: StorageDecodingOperation<AccountInfo?> = createDecodingOperation(
                for: accountInfoStorageWrapper.data,
                chainAsset: chainAsset,
                storagePath: .account
            ) else {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createNormalMappingOperation(
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
            .soraAsset,
            .assetId,
            .token2:
            guard let decodingOperation: StorageDecodingOperation<OrmlAccountInfo?> = createDecodingOperation(
                for: accountInfoStorageWrapper.data,
                chainAsset: chainAsset,
                storagePath: .tokens
            ) else {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createOrmlMappingOperation(
                chainAsset: chainAsset,
                dependingOn: decodingOperation
            )

            return operation
        case .equilibrium:
            guard let decodingOperation: StorageDecodingOperation<EquilibriumAccountInfo?> = createDecodingOperation(
                for: accountInfoStorageWrapper.data,
                chainAsset: chainAsset,
                storagePath: chainAsset.storagePath
            ) else {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createEquilibriumMappingOperation(
                chainAsset: chainAsset,
                dependingOn: decodingOperation
            )

            return operation
        case .assets:
            guard let decodingOperation: StorageDecodingOperation<AssetAccount?> = createDecodingOperation(
                for: accountInfoStorageWrapper.data,
                chainAsset: chainAsset,
                storagePath: .assetsAccount
            ) else {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createAssetMappingOperation(
                chainAsset: chainAsset,
                dependingOn: decodingOperation
            )

            return operation
        }
    }

    private func createZeroBalanceAccountInfoOperations(
        dependingOn fetchOperation: BaseOperation<[AccountInfoStorageWrapper]>,
        keys: [String],
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) -> ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
        let operation = ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
            let rawResult = try fetchOperation.extractNoCancellableResultData()
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

            return zeroBalanceOperations
        }

        return operation
    }

    func createMapChainAssetsWithKeysOperation(
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) -> ClosureOperation<[ChainAssetKey: ChainAsset]> {
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

        return mapChainAssetsWithKeysOperation
    }

    func generateStorageKeys(for chainAssets: [ChainAsset], wallet: MetaAccountModel) -> [String] {
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

        return keys
    }

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

    func createAssetMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<AssetAccount?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation {
            let assetAccount = try decodingOperation.extractNoCancellableResultData()
            let accountInfo = AccountInfo(assetAccount: assetAccount)
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

    private func handleAssetAccount(
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard let decodingOperation: StorageDecodingOperation<AssetAccount?> = createDecodingOperation(
            for: item.data,
            chainAsset: chainAsset,
            storagePath: .assetsAccount
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
                case let .success(assetAccount):
                    let accountInfo = AccountInfo(assetAccount: assetAccount)
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
        result: Swift.Result<EquilibriumAccountInfo?, Error>,
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

    private func handleEthereumAccountInfo(
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        do {
            let accountInfo = try JSONDecoder().decode(AccountInfo?.self, from: item.data)
            completionBlock(chainAsset, accountInfo)
        } catch {
            completionBlock(chainAsset, nil)
        }
    }
}
