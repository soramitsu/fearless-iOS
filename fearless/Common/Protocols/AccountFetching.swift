import Foundation
import RobinHood
import SSFModels

protocol AccountFetching {
    func fetchAllMetaAccounts(
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[MetaAccountModel], Error>) -> Void
    )

    func fetchChainAccounts(
        chain: ChainModel,
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[ChainAccountResponse], Error>) -> Void
    )

    func fetchChainAccount(
        chain: ChainModel,
        address: String,
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<ChainAccountResponse?, Error>) -> Void
    )

    func fetchChainAccountFor(
        meta: MetaAccountModel,
        chain: ChainModel,
        address: String,
        closure: @escaping (Result<ChainAccountResponse?, Error>) -> Void
    ) -> Bool

    func fetchMetaAccount(
        chain: ChainModel,
        address: String,
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<MetaAccountModel?, Error>) -> Void
    )
}

extension AccountFetching {
    func fetchAllMetaAccounts(
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[MetaAccountModel], Error>) -> Void
    ) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    @discardableResult
    func fetchChainAccountFor(
        meta: MetaAccountModel,
        chain: ChainModel,
        address: String,
        closure: @escaping (Result<ChainAccountResponse?, Error>) -> Void
    ) -> Bool {
        let nativeChainAccount = meta.fetch(for: chain.accountRequest())
        if let nativeAddress = nativeChainAccount?.toAddress(), nativeAddress == address {
            closure(.success(nativeChainAccount))
            return true
        }

        for chainAccount in meta.chainAccounts {
            let chainFormat: ChainFormat = chainAccount.ethereumBased ? .ethereum : .substrate(chain.addressPrefix)
            if let chainAddress = try? chainAccount.accountId.toAddress(using: chainFormat),
               chainAddress == address {
                let account = ChainAccountResponse(
                    chainId: chain.chainId,
                    accountId: chainAccount.accountId,
                    publicKey: chainAccount.publicKey,
                    name: meta.name,
                    cryptoType: CryptoType(rawValue: meta.substrateCryptoType) ?? .sr25519,
                    addressPrefix: chain.addressPrefix,
                    isEthereumBased: chainAccount.ethereumBased,
                    isChainAccount: true,
                    walletId: meta.metaId
                )
                closure(.success(account))
                return true
            }
        }
        closure(.failure(ChainAccountFetchingError.accountNotExists))
        return false
    }

    func fetchChainAccount(
        chain: ChainModel,
        address: String,
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<ChainAccountResponse?, Error>) -> Void
    ) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    guard let accounts = try? result.get() else {
                        closure(.failure(ChainAccountFetchingError.accountNotExists))
                        return
                    }

                    for meta in accounts {
                        let found = fetchChainAccountFor(
                            meta: meta,
                            chain: chain,
                            address: address,
                            closure: closure
                        )

                        if found {
                            return
                        }
                    }
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func fetchChainAccounts(
        chain: ChainModel,
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[ChainAccountResponse], Error>) -> Void
    ) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    guard let accounts = try? result.get() else {
                        closure(.failure(ChainAccountFetchingError.accountNotExists))
                        return
                    }

                    var responses: [ChainAccountResponse] = []

                    for meta in accounts {
                        if let nativeChainAccount = meta.fetch(for: chain.accountRequest()) {
                            responses.append(nativeChainAccount)
                        }

                        for chainAccount in meta.chainAccounts {
                            responses.append(ChainAccountResponse(
                                chainId: chain.chainId,
                                accountId: chainAccount.accountId,
                                publicKey: chainAccount.publicKey,
                                name: meta.name,
                                cryptoType: CryptoType(rawValue: meta.substrateCryptoType) ?? .sr25519,
                                addressPrefix: chain.addressPrefix,
                                isEthereumBased: false,
                                isChainAccount: true,
                                walletId: meta.metaId
                            ))
                        }
                    }

                    closure(.success(responses))
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func fetchMetaAccount(
        chain: ChainModel,
        address: String,
        from repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<MetaAccountModel?, Error>) -> Void
    ) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    guard let accounts = try? result.get() else {
                        closure(.failure(ChainAccountFetchingError.accountNotExists))
                        return
                    }

                    for meta in accounts {
                        let nativeChainAccount = meta.fetch(for: chain.accountRequest())
                        if let nativeAddress = nativeChainAccount?.toAddress(), nativeAddress == address {
                            closure(.success(meta))
                            return
                        }

                        for chainAccount in meta.chainAccounts {
                            let chainFormat: ChainFormat = chainAccount.ethereumBased ? .ethereum : .substrate(chain.addressPrefix)
                            if let chainAddress = try? chainAccount.accountId.toAddress(using: chainFormat),
                               chainAddress == address {
                                closure(.success(meta))
                                return
                            }
                        }
                        closure(.failure(ChainAccountFetchingError.accountNotExists))
                        return
                    }
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                    return
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
