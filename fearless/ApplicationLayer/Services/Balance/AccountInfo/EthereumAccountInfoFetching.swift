import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import SSFModels
import RobinHood

final actor EthereumAccountInfoFetching {
    private let operationQueue: OperationQueue
    private let chainRegistry: ChainRegistryProtocol

    init(operationQueue: OperationQueue, chainRegistry: ChainRegistryProtocol) {
        self.operationQueue = operationQueue
        self.chainRegistry = chainRegistry
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
            ws.getBalance(address: ethereumAddress, block: .latest) { resp in
                if let balance = resp.result {
                    let accountInfo = AccountInfo(ethBalance: balance.quantity)
                    return continuation.resume(with: .success(accountInfo))
                } else if let error = resp.error {
                    return continuation.resume(with: .failure(error))
                } else {
                    return continuation.resume(with: .success(nil))
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
}

extension EthereumAccountInfoFetching: AccountInfoFetchingProtocol {
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
                completionBlock(chainAsset, accountInfo)
            case .erc20, .bep20:
                let accountInfo = try await fetchERC20Balance(for: chainAsset, address: address)
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

                for try await accountInfoByChainAsset in group {
                    result[accountInfoByChainAsset.0] = accountInfoByChainAsset.1
                }

                return result
            }

            completionBlock(balances)
        }
    }
}
