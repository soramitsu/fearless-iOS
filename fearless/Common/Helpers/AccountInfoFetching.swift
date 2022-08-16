import Foundation
import RobinHood

protocol AccountInfoFetchingProtocol {
    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    )
}

final class AccountInfoFetching: AccountInfoFetchingProtocol {
    private let accountInfoRepository: AnyDataProviderRepository<ChainStorageItem>
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue

    init(
        accountInfoRepository: AnyDataProviderRepository<ChainStorageItem>,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountInfoRepository = accountInfoRepository
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
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
                    .stable:
                    self?.handleOrmlAccountInfo(
                        chainAsset: chainAsset,
                        item: item,
                        completionBlock: completionBlock
                    )
                case .equilibrium:
                    self?.handleEquilibrium(
                        chainAsset: chainAsset,
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
    func handleOrmlAccountInfo(
        chainAsset: ChainAsset,
        item: ChainStorageItem,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard
            let runtimeCodingService = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            completionBlock(chainAsset, nil)
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<OrmlAccountInfo?>(
            path: .tokens,
            data: item.data
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
        operationQueue.addOperations([decodingOperation, codingFactoryOperation], waitUntilFinished: false)
    }

    func handleAccountInfo(
        chainAsset: ChainAsset,
        item: ChainStorageItem,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard
            let runtimeCodingService = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            completionBlock(chainAsset, nil)
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<AccountInfo?>(
            path: .account,
            data: item.data
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
        operationQueue.addOperations([decodingOperation, codingFactoryOperation], waitUntilFinished: false)
    }

    func handleEquilibrium(
        chainAsset: ChainAsset,
        item: ChainStorageItem,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        guard
            let runtimeCodingService = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            completionBlock(chainAsset, nil)
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<EquilibriumAccountInfo?>(
            path: .eqBalances,
            data: item.data
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

        decodingOperation.completionBlock = {
            DispatchQueue.main.async {
                guard let result = decodingOperation.result else {
                    completionBlock(chainAsset, nil)
                    return
                }

                switch result {
                case let .success(equilibriumAccountInfo):
                    let accountInfo = AccountInfo(equilibriumAccountInfo: equilibriumAccountInfo)
                    completionBlock(chainAsset, accountInfo)
                case .failure:
                    completionBlock(chainAsset, nil)
                }
            }
        }
        operationQueue.addOperations([decodingOperation, codingFactoryOperation], waitUntilFinished: false)
    }
}
