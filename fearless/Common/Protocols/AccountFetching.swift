import Foundation
import RobinHood

protocol AccountFetching {
    func fetchAccount(
        for address: AccountAddress,
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    )

    func fetchAllAccounts(
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[AccountItem], Error>) -> Void
    )

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
}

extension AccountFetching {
    func fetchAccount(
        for address: AccountAddress,
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    ) {
        let operation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

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

    func fetchAllAccounts(
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[AccountItem], Error>) -> Void
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

                    var response: ChainAccountResponse?

                    for meta in accounts {
                        let nativeChainAccount = meta.fetch(for: chain.accountRequest())
                        if nativeChainAccount?.toAddress() == address {
                            response = nativeChainAccount
                            break
                        }

                        for chainAccount in meta.chainAccounts {
                            if chainAccount.toAddress(addressPrefix: chain.addressPrefix) == address {
                                response = ChainAccountResponse(
                                    chainId: chain.chainId,
                                    accountId: chainAccount.accountId,
                                    publicKey: chainAccount.publicKey,
                                    name: meta.name,
                                    cryptoType: CryptoType(rawValue: meta.substrateCryptoType) ?? .sr25519,
                                    addressPrefix: chain.addressPrefix,
                                    isEthereumBased: false,
                                    isChainAccount: true
                                )
                            }
                        }
                    }

                    closure(.success(response))
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
                                isChainAccount: true
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
}
