import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import SSFModels
import RobinHood

final actor EthereumRemoteBalanceFetching {
    private let chainRegistry: ChainRegistryProtocol
    private let repositoryWrapper: EthereumBalanceRepositoryCacheWrapper

    init(
        chainRegistry: ChainRegistryProtocol,
        repositoryWrapper: EthereumBalanceRepositoryCacheWrapper
    ) {
        self.chainRegistry = chainRegistry
        self.repositoryWrapper = repositoryWrapper
    }

    nonisolated private func fetchEthereumBalanceOperation(for chainAsset: ChainAsset, address: String) -> AwaitOperation<[ChainAsset: AccountInfo?]> {
        AwaitOperation { [weak self] in
            let accountInfo = try await self?.fetchETHBalance(for: chainAsset, address: address)
            return [chainAsset: accountInfo]
        }
    }

    nonisolated private func fetchErc20BalanceOperation(for chainAsset: ChainAsset, address: String) -> AwaitOperation<[ChainAsset: AccountInfo?]> {
        AwaitOperation { [weak self] in
            let accountInfo = try await self?.fetchERC20Balance(for: chainAsset, address: address)
            return [chainAsset: accountInfo]
        }
    }

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
                    let accountInfo = AccountInfo(ethBalance: balance.quantity)
                    unwrapedContinuation.resume(with: .success(accountInfo))
                    nillableContinuation = nil
                } else if let error = resp.error {
                    unwrapedContinuation.resume(with: .failure(error))
                    nillableContinuation = nil
                } else {
                    unwrapedContinuation.resume(with: .success(nil))
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
                    let accountInfo = AccountInfo(ethBalance: balance)
                    unwrapedContinuation.resume(with: .success(accountInfo))
                    nillableContinuation = nil
                } else if let error = error {
                    unwrapedContinuation.resume(with: .failure(error))
                    nillableContinuation = nil
                } else {
                    unwrapedContinuation.resume(with: .success(nil))
                    nillableContinuation = nil
                }
            })
        }
    }

    nonisolated private func cache(accountInfo: AccountInfo?, chainAsset: ChainAsset, accountId: AccountId) throws {
        let storagePath = chainAsset.storagePath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        try repositoryWrapper.save(data: accountInfo, identifier: localKey)
    }
}

extension EthereumRemoteBalanceFetching: AccountInfoFetchingProtocol {
    nonisolated func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        Task {
            guard let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) else {
                completionBlock(chainAsset, nil)
                return
            }

            switch chainAsset.asset.ethereumType {
            case .normal:
                let accountInfo = try await fetchETHBalance(for: chainAsset, address: address)
                try cache(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
                completionBlock(chainAsset, accountInfo)
            case .erc20, .bep20:
                let accountInfo = try await fetchERC20Balance(for: chainAsset, address: address)
                try cache(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
                completionBlock(chainAsset, accountInfo)
            case .none:
                break
            }
        }
    }

    nonisolated func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        Task {
            let balances = try await withThrowingTaskGroup(of: (ChainAsset, AccountInfo?).self, returning: [ChainAsset: AccountInfo?].self) { [weak self] group in
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

                for try await accountInfoByChainAsset in group {
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

            completionBlock(balances)
        }
    }
}
