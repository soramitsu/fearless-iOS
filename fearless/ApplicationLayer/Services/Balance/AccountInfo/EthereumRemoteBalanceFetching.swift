import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import SSFModels

final actor EthereumRemoteBalanceFetching {
    /// A balance read the node has not answered by then counts as an outage, and the network moves on to its next node.
    static let nodeReadTimeout: TimeInterval = 15

    private let chainRegistry: ChainRegistryProtocol
    private let repositoryWrapper: BalanceRepositoryCacheWrapper
    private let nodeReadTimeout: TimeInterval

    init(
        chainRegistry: ChainRegistryProtocol,
        repositoryWrapper: BalanceRepositoryCacheWrapper,
        nodeReadTimeout: TimeInterval = EthereumRemoteBalanceFetching.nodeReadTimeout
    ) {
        self.chainRegistry = chainRegistry
        self.repositoryWrapper = repositoryWrapper
        self.nodeReadTimeout = nodeReadTimeout
    }

    private func fetchETHBalance(for chainAsset: ChainAsset, address: String) async throws -> AccountInfo? {
        let ethereumAddress = try EthereumAddress(rawAddress: address.hexToBytes())

        return try await readOnNode(of: chainAsset.chain) { ws, completion in
            ws.getBalance(address: ethereumAddress, block: .latest) { resp in
                if let balance = resp.result {
                    completion(.success(AccountInfo(ethBalance: balance.quantity)))
                } else if let error = resp.error {
                    completion(.failure(error))
                } else {
                    completion(.success(nil))
                }
            }
        }
    }

    private func fetchERC20Balance(for chainAsset: ChainAsset, address: String) async throws -> AccountInfo? {
        let contractAddress = try EthereumAddress(hex: chainAsset.asset.id, eip55: false)
        let ethAddress = try EthereumAddress(rawAddress: address.hexToBytes())

        return try await readOnNode(of: chainAsset.chain) { ws, completion in
            let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
            contract.balanceOf(address: ethAddress).call(completion: { response, error in
                if let response, let balance = response["_balance"] as? BigUInt {
                    completion(.success(AccountInfo(ethBalance: balance)))
                } else if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(nil))
                }
            })
        }
    }

    /// Reads on the network's node within `nodeReadTimeout`. When the node fails, the network moves on to its next
    /// node and the read is tried there once, so a dead node costs a moment instead of the balance.
    private func readOnNode<T>(
        of chain: ChainModel,
        _ read: @escaping (Web3.Eth, @escaping (Swift.Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        guard var connection = chainRegistry.getEthereumConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        var attempt = 0
        while true {
            do {
                let node = connection
                return try await Self.firstResult(within: nodeReadTimeout) { completion in
                    read(node, completion)
                }
            } catch {
                guard EthereumNodeFailure.isNodeFailure(error) else {
                    throw error
                }

                let next = chainRegistry.failoverEthereumConnection(for: chain.chainId, failed: connection)
                guard attempt == 0, let next else {
                    throw error
                }
                connection = next
                attempt += 1
            }
        }
    }

    /// The first result `read` reports, or `EthereumNodeError.timeout` when it reports none within `timeout`.
    private static func firstResult<T>(
        within timeout: TimeInterval,
        _ read: @escaping (@escaping (Swift.Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let resumer = SingleResumption(continuation)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                resumer.resume(with: .failure(EthereumNodeError.timeout))
            }
            read { resumer.resume(with: $0) }
        }
    }

    private func cache(accountInfo: AccountInfo?, chainAsset: ChainAsset, accountId: AccountId) throws {
        guard let accountInfo else { return }
        let storagePath = chainAsset.storagePath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        try repositoryWrapper.save(data: accountInfo, identifier: localKey)
    }
}

extension EthereumRemoteBalanceFetching: AccountInfoFetchingProtocol {
    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> (ChainAsset, AccountInfo?) {
        guard let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) else {
            return (chainAsset, nil)
        }

        switch chainAsset.asset.ethereumType {
        case .normal:
            let accountInfo = try await fetchETHBalance(for: chainAsset, address: address)
            try cache(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
            return (chainAsset, accountInfo)
        case .erc20, .bep20:
            let accountInfo = try await fetchERC20Balance(for: chainAsset, address: address)
            try cache(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
            return (chainAsset, accountInfo)
        case .none:
            return (chainAsset, nil)
        }
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        let balances = try await withThrowingTaskGroup(of: (ChainAsset, AccountInfo?)?.self, returning: [ChainAsset: AccountInfo?].self) { [weak self] group in
            guard let strongSelf = self else {
                return [:]
            }

            let chainAssets = chainAssets.filter { $0.chain.isEthereum }

            chainAssets.forEach { chainAsset in
                group.addTask {
                    guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
                        return (chainAsset, nil)
                    }

                    switch chainAsset.asset.ethereumType {
                    case .normal:
                        let accountInfo = try await strongSelf.fetchETHBalance(for: chainAsset, address: address)
                        return (chainAsset, accountInfo)
                    case .erc20, .bep20:
                        let accountInfo = try await strongSelf.fetchERC20Balance(for: chainAsset, address: address)
                        return (chainAsset, accountInfo)
                    case .none:
                        return (chainAsset, nil)
                    }
                }
            }

            var result: [ChainAsset: AccountInfo?] = [:]

            for try await accountInfoByChainAsset in group.compactMap({ $0 }) {
                let chainAsset = accountInfoByChainAsset.0
                let accountInfo = accountInfoByChainAsset.1
                if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
                    if let self {
                        try await self.cache(
                            accountInfo: accountInfo,
                            chainAsset: chainAsset,
                            accountId: accountId
                        )
                    }
                }

                result[chainAsset] = accountInfo
            }

            return result
        }

        return balances
    }

    nonisolated func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        Task {
            do {
                let result = try await fetch(for: chainAsset, accountId: accountId)
                completionBlock(result.0, result.1)
            } catch {
                completionBlock(chainAsset, nil)
            }
        }
    }

    nonisolated func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        Task {
            do {
                let result = try await fetch(for: chainAssets, wallet: wallet)
                completionBlock(result)
            } catch {
                completionBlock([:])
            }
        }
    }

    func fetchByUniqKey(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        let accountInfos = try await fetch(for: chainAssets, wallet: wallet)
        let mapped: [(ChainAssetKey, AccountInfo?)] = accountInfos.compactMap { chainAsset, accountInfo in
            let request = chainAsset.chain.accountRequest()
            guard let accountId = wallet.fetch(for: request)?.accountId else {
                return nil
            }
            let key = chainAsset.uniqueKey(accountId: accountId)
            return (key, accountInfo)
        }
        return Dictionary(uniqueKeysWithValues: mapped)
    }
}

/// Resumes a continuation with the first result it is given: transports may answer a request twice, and a timed-out
/// read may still be answered.
private final class SingleResumption<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Swift.Result<T, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()

        pending?.resume(with: result)
    }
}
