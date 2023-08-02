import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import SSFModels
import RobinHood

final class EthereumAccountInfoFetching: AccountInfoFetchingProtocol {
    private let operationQueue: OperationQueue

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }

    func fetch(
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
            case .erc20:
                let accountInfo = try await fetchERC20Balance(for: chainAsset, address: address)
                completionBlock(chainAsset, accountInfo)
            case .none:
                break
            }
        }
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        let chainAssets = chainAssets.filter { $0.chain.isEthereum }
        let accountInfoOperations: [AwaitOperation<[ChainAsset: AccountInfo?]>] = chainAssets.filter { $0.chain.isEthereum }.compactMap { chainAsset in
            guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
                return nil
            }

            switch chainAsset.asset.ethereumType {
            case .normal:
                return fetchEthereumBalanceOperation(for: chainAsset, address: address)
            case .erc20:
                return fetchErc20BalanceOperation(for: chainAsset, address: address)
            case .none:
                return nil
            }
        }

        let finishOperation = ClosureOperation {
            let accountInfos = accountInfoOperations.compactMap { try? $0.extractNoCancellableResultData() }.flatMap { $0 }
            let accountInfoByChainAsset = Dictionary(accountInfos, uniquingKeysWith: { _, last in last })

            completionBlock(accountInfoByChainAsset)
        }

        accountInfoOperations.forEach { finishOperation.addDependency($0) }

        operationQueue.addOperations([finishOperation] + accountInfoOperations, waitUntilFinished: true)
    }

    private func fetchEthereumBalanceOperation(for chainAsset: ChainAsset, address: String) -> AwaitOperation<[ChainAsset: AccountInfo?]> {
        AwaitOperation { [weak self] in
            let accountInfo = try await self?.fetchETHBalance(for: chainAsset, address: address)
            return [chainAsset: accountInfo]
        }
    }

    private func fetchErc20BalanceOperation(for chainAsset: ChainAsset, address: String) -> AwaitOperation<[ChainAsset: AccountInfo?]> {
        AwaitOperation { [weak self] in
            let accountInfo = try await self?.fetchERC20Balance(for: chainAsset, address: address)
            return [chainAsset: accountInfo]
        }
    }

    private func fetchETHBalance(for chainAsset: ChainAsset, address: String) async throws -> AccountInfo? {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let eth = try chainAsset.chain.rpcEth()
                let ethereumAddress = try EthereumAddress(rawAddress: address.hexToBytes())
                eth.getBalance(address: ethereumAddress, block: .latest) { resp in
                    if let balance = resp.result {
                        let accountInfo = AccountInfo(ethBalance: balance.quantity)
                        return continuation.resume(with: .success(accountInfo))
                    } else if let error = resp.error {
                        return continuation.resume(with: .failure(error))
                    } else {
                        return continuation.resume(with: .success(nil))
                    }
                }
            } catch {
                return continuation.resume(with: .failure(error))
            }
        }
    }

    private func fetchERC20Balance(for chainAsset: ChainAsset, address: String) async throws -> AccountInfo? {
        let eth = try chainAsset.chain.rpcEth()
        let contractAddress = try EthereumAddress(hex: chainAsset.asset.id, eip55: false)
        let contract = eth.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let ethAddress = try EthereumAddress(rawAddress: address.hexToBytes())
        return try await withCheckedThrowingContinuation { continuation in
            contract.balanceOf(address: ethAddress).call(completion: { response, error in
                if let response = response, let balance = response["_balance"] as? BigUInt {
                    let accountInfo = AccountInfo(ethBalance: balance)
                    return continuation.resume(with: .success(accountInfo))
                } else if let error = error {
                    return continuation.resume(with: .failure(error))
                } else {
                    return continuation.resume(with: .success(nil))
                }
            })
        }
    }
}
