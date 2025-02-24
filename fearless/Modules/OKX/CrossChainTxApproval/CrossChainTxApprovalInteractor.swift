import UIKit
import BigInt
import SSFModels

enum CrossChainFundsPermissionInteractorError: Error {
    case noApproveOrRevokeNeeded
}

protocol CrossChainFundsPermissionInteractorOutput: AnyObject {}

final class CrossChainFundsPermissionInteractor {
    // MARK: - Private properties
    private weak var output: CrossChainFundsPermissionInteractorOutput?
    
    private let swapService: OKXEthereumSwapService
    private let okxService: OKXDexAggregatorService
    private let wallet: MetaAccountModel
    private let swapFromChainAsset: ChainAsset
    private let balanceFetching: EthereumRemoteBalanceFetching
    private let accountInfoFetchingProvider: AccountInfoFetching
    private let amount: String
    private let swap: CrossChainSwap
    private var approveTransaction: OKXApproveTransaction?
    
    init(
        swapService: OKXEthereumSwapService,
        wallet: MetaAccountModel,
        swapFromChainAsset: ChainAsset,
        okxService: OKXDexAggregatorService,
        amount: String,
        swap: CrossChainSwap,
        balanceFetching: EthereumRemoteBalanceFetching,
        accountInfoFetchingProvider: AccountInfoFetching
    ) {
        self.swapService = swapService
        self.wallet = wallet
        self.swapFromChainAsset = swapFromChainAsset
        self.balanceFetching = balanceFetching
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.okxService = okxService
        self.amount = amount
        self.swap = swap
    }
    
    
    private func fetchApproveTransaction() async throws -> OKXApproveTransaction {
        guard let amount = swap.fromAmount else {
            throw CrossChainSwapConfirmInteractorError.approveInvalidAmount
        }

        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: swapFromChainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters, preferredDataSourceType: .combine)

        guard
            let fromTokenAddress = fromTokens.data?.first(where: { $0.tokenSymbol.lowercased() == swapFromChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }
        let parameters = OKXDexApproveRequestParameters(chainId: swapFromChainAsset.chain.chainId, tokenContractAddress: fromTokenAddress, approveAmount: amount)
        let approveTransaction = try await okxService.fetchApproveTransactionInfo(parameters: parameters).data?.first

        guard let approveTransaction else {
            throw CrossChainSwapConfirmInteractorError.invalidApproveTransactionResponse
        }

        return approveTransaction
    }
    
    private func fetchLocalBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?] {
        try await accountInfoFetchingProvider.fetchByUniqKey(for: chainAssets, wallet: wallet)
    }

    private func fetchRemoteBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?] {
        try await balanceFetching.fetchByUniqKey(for: chainAssets, wallet: wallet)
    }
    
    private func estimateApproveFee() async throws -> BigUInt {
        let approveTransaction = try await fetchApproveTransaction()
        self.approveTransaction = approveTransaction
        let fee = try await swapService.estimateFee(
            approveTransaction: approveTransaction,
            chain: swapFromChainAsset.chain,
            chainAsset: swapFromChainAsset
        )
        return fee
    }
    
    private func estimateRevokeFee(dexTokenApproveAddress: String) async throws -> BigUInt {
        let fee = try await swapService.estimateFeeForApproveTx(
            dexTokenApproveAddress: dexTokenApproveAddress,
            chainAsset: swapFromChainAsset
        )
        return fee
    }
    
    private func approveSpending() async throws -> String {
        var transaction = approveTransaction
    
        if transaction == nil {
            transaction = try await fetchApproveTransaction()
        }
        
        guard let transaction else {
            throw CrossChainSwapConfirmInteractorError.invalidApproveTransactionResponse
        }

        return try await swapService.approve(
            approveTransaction: transaction,
            chain: swapFromChainAsset.chain,
            chainAsset: swapFromChainAsset
        )
    }
    
    private func revoke(dexTokenApproveAddress: String) async throws -> String {
        let hash = try await swapService.revoke(chainAsset: swapFromChainAsset, dexTokenApproveAddress: dexTokenApproveAddress)
        return hash
    }
}

// MARK: - CrossChainFundsPermissionInteractorInput
extension CrossChainFundsPermissionInteractor: CrossChainFundsPermissionInteractorInput {
    func fetchBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey : AccountInfo?] {
        async let local = try await fetchLocalBalance(for: chainAssets)
        async let remote = try await fetchRemoteBalance(for: chainAssets)

        let merged = try await local.merging(remote) { local, remote in remote ?? local }
        return merged
    }
    
    func setup(with output: CrossChainFundsPermissionInteractorOutput) {
        self.output = output
    }
    
    func submit(mode: CrossChainFundsPermissionMode) async throws -> String {
        switch mode {
        case .none:
            throw CrossChainFundsPermissionInteractorError.noApproveOrRevokeNeeded
        case .approve:
            return try await approveSpending()
        case .revoke(let dexTokenApproveAddress):
            return try await revoke(dexTokenApproveAddress: dexTokenApproveAddress)
        }
    }
    
    func estimateFee(mode: CrossChainFundsPermissionMode) async throws -> BigUInt {
        switch mode {
        case .none:
            throw CrossChainFundsPermissionInteractorError.noApproveOrRevokeNeeded
        case .approve:
            return try await estimateApproveFee()
        case .revoke(let dexTokenApproveAddress):
            return try await estimateRevokeFee(dexTokenApproveAddress: dexTokenApproveAddress)
        }
    }
    
    func checkTransactionSucceed(txHash: String) async throws -> Bool {
        return try await swapService.isTransactionExists(txHash: txHash)
    }
}
