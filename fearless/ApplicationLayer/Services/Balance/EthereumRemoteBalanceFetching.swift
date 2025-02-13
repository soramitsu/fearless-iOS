import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import SSFModels
import RobinHood
import SSFCrypto

enum EthereumRemoteBalanceFetchingError: Error {
    case notFound
}

actor EthereumRemoteBalanceFetching: AccountInfoRemoteService {
    private let chainRegistry: ChainRegistryProtocol
    private let repositoryWrapper: BalanceRepositoryCacheWrapper

    init(
        chainRegistry: ChainRegistryProtocol,
        repositoryWrapper: BalanceRepositoryCacheWrapper
    ) {
        self.chainRegistry = chainRegistry
        self.repositoryWrapper = repositoryWrapper
    }

    // MARK: - AccountInfoRemoteService

    func fetchAccountInfos(
        for chain: SSFModels.ChainModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        let chainAssets = chain.chainAssets
        let response = try await fetch(for: chainAssets, wallet: wallet)
        let mapped = response.map {
            ($0.key.chainAssetId, $0.value)
        }
        let map = Dictionary(uniqueKeysWithValues: mapped)
        return map
    }

    func fetchAccountInfo(
        for chainAsset: SSFModels.ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo? {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            throw ConvenienceError(error: "Missing account id for \(chainAsset.debugName)")
        }
        let accountInfo = try await fetch(
            for: chainAsset,
            accountId: accountId
        )
        return accountInfo
    }

    func fetchAccountInfos(
        for chainAssets: [SSFModels.ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        try await fetchByUniqKey(for: chainAssets, wallet: wallet)
    }

    func fetchByUniqKey(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        let uniqueChainAssets = chainAssets.uniq(predicate: \.asset.id)
        let accountInfos = try await fetch(for: uniqueChainAssets, wallet: wallet)
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

    // MARK: - Private methods

    private func fetchETHBalance(for chainAsset: ChainAsset, address: String) async throws -> AccountInfo? {
        guard let ws = chainRegistry.getEthereumConnection(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }
        let ethereumAddress = try EthereumAddress(rawAddress: address.hexToBytes())

        return try await withCheckedThrowingContinuation { continuation in
            var nillableContinuation: CheckedContinuation<AccountInfo?, Error>? = continuation

            ws.getBalance(address: ethereumAddress, block: .latest) { resp in
                guard let unwrapedContinuation = nillableContinuation else {
                    return
                }
                if let balance = resp.result {
                    let accountInfo = AccountInfo(balance: balance.quantity)
                    unwrapedContinuation.resume(with: .success(accountInfo))
                    nillableContinuation = nil
                } else if let error = resp.error {
                    unwrapedContinuation.resume(with: .failure(error))
                    nillableContinuation = nil
                } else {
                    unwrapedContinuation.resume(with: .failure(EthereumRemoteBalanceFetchingError.notFound))
                    nillableContinuation = nil
                }
            }
        }
    }

    private func fetchERC20Balance(for chainAsset: ChainAsset, address: String) async throws -> AccountInfo? {
        guard let ws = chainRegistry.getEthereumConnection(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let contractAddress = try EthereumAddress(hex: chainAsset.asset.id, eip55: false)
        let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let ethAddress = try EthereumAddress(rawAddress: address.hexToBytes())
        return try await withCheckedThrowingContinuation { continuation in
            var nillableContinuation: CheckedContinuation<AccountInfo?, Error>? = continuation

            contract.balanceOf(address: ethAddress).call(completion: { response, error in
                guard let unwrapedContinuation = nillableContinuation else {
                    return
                }

                if let response = response, let balance = response["_balance"] as? BigUInt {
                    let accountInfo = AccountInfo(balance: balance)
                    unwrapedContinuation.resume(with: .success(accountInfo))
                    nillableContinuation = nil
                } else if let error = error {
                    unwrapedContinuation.resume(with: .failure(error))
                    nillableContinuation = nil
                } else {
                    unwrapedContinuation.resume(with: .failure(EthereumRemoteBalanceFetchingError.notFound))
                    nillableContinuation = nil
                }
            })
        }
    }

    private func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        let balances = try await withThrowingTaskGroup(of: (ChainAsset, AccountInfo?)?.self, returning: [ChainAsset: AccountInfo?].self) { [weak self] group in
            guard let strongSelf = self else {
                return [:]
            }

            let chainAssets = chainAssets.filter { $0.chain.ecosystem.isEthereum }

            chainAssets.forEach { chainAsset in
                group.addTask {
                    guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
                        return (chainAsset, nil)
                    }

                    switch chainAsset.asset.assetType.ethereumAssetType {
                    case .normal:
                        do {
                            let accountInfo = try await strongSelf.fetchETHBalance(for: chainAsset, address: address)
                            return (chainAsset, accountInfo)
                        } catch {
                            return (chainAsset, nil)
                        }
                    case .erc20, .bep20:
                        do {
                            let accountInfo = try await strongSelf.fetchERC20Balance(for: chainAsset, address: address)
                            return (chainAsset, accountInfo)
                        } catch {
                            return (chainAsset, nil)
                        }
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
                    try self?.cache(
                        accountInfo: accountInfo,
                        chainAsset: chainAsset,
                        accountId: accountId
                    )
                }

                result[chainAsset] = accountInfo
            }

            return result
        }

        return balances
    }

    private func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> AccountInfo? {
        guard let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) else {
            return nil
        }

        switch chainAsset.asset.assetType.ethereumAssetType {
        case .normal:
            let accountInfo = try await fetchETHBalance(for: chainAsset, address: address)
            try cache(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
            return accountInfo
        case .erc20, .bep20:
            let accountInfo = try await fetchERC20Balance(for: chainAsset, address: address)
            try cache(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
            return accountInfo
        case .none:
            return nil
        }
    }

    nonisolated private func cache(accountInfo: AccountInfo?, chainAsset: ChainAsset, accountId: AccountId) throws {
        guard let accountInfo else {
            return
        }
        
        let storagePath = chainAsset.storagePath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        try repositoryWrapper.save(data: accountInfo, identifier: localKey)
    }
}
