import Foundation
import SSFModels
import Web3
import Web3ContractABI
import RobinHood

final class EthereumWalletRemoteSubscriptionService {
    private let chainRegistry: ChainRegistryProtocol
    private let logger: LoggerProtocol
    private let repository: AnyDataProviderRepository<AccountInfoStorageWrapper>
    private let operationManager: OperationManagerProtocol
    private let repositoryWrapper: EthereumBalanceRepositoryCacheWrapper

    init(
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol,
        repository: AnyDataProviderRepository<AccountInfoStorageWrapper>,
        operationManager: OperationManagerProtocol,
        repositoryWrapper: EthereumBalanceRepositoryCacheWrapper
    ) {
        self.chainRegistry = chainRegistry
        self.logger = logger
        self.repository = repository
        self.operationManager = operationManager
        self.repositoryWrapper = repositoryWrapper
    }

    private func handleNewBlock(ws: Web3.Eth, chainAsset: ChainAsset, accountId: AccountId) throws {
        switch chainAsset.asset.ethereumType {
        case .normal:
            try fetchEthBalance(for: chainAsset, ws: ws, accountId: accountId)
        case .erc20, .bep20:
            try fetchERC20Balance(for: chainAsset, ws: ws, accountId: accountId)
        case .none:
            break
        }
    }

    private func fetchEthBalance(for chainAsset: ChainAsset, ws: Web3.Eth, accountId: AccountId) throws {
        let address = try AddressFactory.address(for: accountId, chain: chainAsset.chain)
        let ethereumAddress = try EthereumAddress(rawAddress: address.hexToBytes())

        ws.getBalance(address: ethereumAddress, block: .latest) { [weak self] resp in
            if let balance = resp.result {
                let accountInfo = AccountInfo(ethBalance: balance.quantity)
                try? self?.handle(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
            }
        }
    }

    private func fetchERC20Balance(for chainAsset: ChainAsset, ws: Web3.Eth, accountId: AccountId) throws {
        let address = try AddressFactory.address(for: accountId, chain: chainAsset.chain)
        let contractAddress = try EthereumAddress(hex: chainAsset.asset.id, eip55: false)
        let contract = ws.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let ethAddress = try EthereumAddress(rawAddress: address.hexToBytes())
        contract.balanceOf(address: ethAddress).call(completion: { [weak self] response, _ in
            if let response = response, let balance = response["_balance"] as? BigUInt {
                let accountInfo = AccountInfo(ethBalance: balance)
                try? self?.handle(accountInfo: accountInfo, chainAsset: chainAsset, accountId: accountId)
            }
        })
    }

    private func handle(accountInfo: AccountInfo?, chainAsset: ChainAsset, accountId: AccountId) throws {
        let storagePath = chainAsset.storagePath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )

        try repositoryWrapper.save(data: accountInfo, identifier: localKey)
    }
}

extension EthereumWalletRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chainAsset: ChainAsset,
        queue _: DispatchQueue?,
        closure _: RemoteSubscriptionClosure?
    ) async -> String? {
        let uuid = await withUnsafeContinuation { continuation in
            guard let ws = chainRegistry.getEthereumConnection(for: chainAsset.chain.chainId) else {
                return
            }

            try? handleNewBlock(ws: ws, chainAsset: chainAsset, accountId: accountId)

            do {
                try ws.subscribeToNewHeads { resp in
                    continuation.resume(returning: resp.result)
                } onEvent: { [weak self]
                    _ in
                    try? self?.handleNewBlock(ws: ws, chainAsset: chainAsset, accountId: accountId)
                }
            } catch {
                return continuation.resume(returning: nil)
                logger.error("EthereumWalletRemoteSubscriptionService:attachToAccountInfo:error: \(error.localizedDescription)")
            }
        }

        guard let uuid = uuid else {
            return nil
        }

        return uuid
    }

    func detachFromAccountInfo(
        for uuid: String,
        chainAssetKey: ChainAssetKey,
        queue _: DispatchQueue?,
        closure _: RemoteSubscriptionClosure?
    ) {
        guard
            let chainId = chainAssetKey.components(separatedBy: ":")[safe: 2],
            let ws = chainRegistry.getEthereumConnection(for: chainId)
        else {
            return
        }

        do {
            try ws.unsubscribe(subscriptionId: uuid) { _ in
            }
        } catch {
            logger.error("EthereumWalletRemoteSubscriptionService:detachFromAccountInfo:error: \(error.localizedDescription)")
        }
    }
}
