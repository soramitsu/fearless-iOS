import UIKit
import SSFModels
import BigInt

enum CrossChainSwapSetupInteractorError: Error {
    case cannotFindTokenAddress
    case accountNotFound
}

protocol CrossChainSwapSetupInteractorOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

final class CrossChainSwapSetupInteractor: CrossChainBaseInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainSwapSetupInteractorOutput?
    private let wallet: MetaAccountModel
    private let okxService: OKXDexAggregatorService
    private let balanceFetching: EthereumRemoteBalanceFetching
    private let accountInfoFetchingProvider: AccountInfoFetching
    private let assetFetching: MultichainAssetFetching
    
    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel,
        balanceFetching: EthereumRemoteBalanceFetching,
        accountInfoFetchingProvider: AccountInfoFetching,
        dependencyContainer: CrossChainDependencyContainer,
        assetFetching: MultichainAssetFetching
    ) {
        self.okxService = okxService
        self.wallet = wallet
        self.balanceFetching = balanceFetching
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.assetFetching = assetFetching
        
        super.init(dependencyContainer: dependencyContainer)
    }

    private func fetchLocalBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?] {
        try await accountInfoFetchingProvider.fetchByUniqKey(for: chainAssets, wallet: wallet)
    }

    private func fetchRemoteBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?] {
        try await balanceFetching.fetchByUniqKey(for: chainAssets, wallet: wallet)
    }
}

// MARK: - CrossChainSwapSetupInteractorInput

extension CrossChainSwapSetupInteractor: CrossChainSwapSetupInteractorInput {
    func setup(with output: CrossChainSwapSetupInteractorOutput) {
        self.output = output
    }

    func fetchDexs(chainAsset: ChainAsset) async throws -> OKXResponse<OKXLiquiditySource> {
        let parameters = OKXDexLiquiditySourceRequestParameters(chainId: chainAsset.chain.chainId)
        return try await okxService.fetchLiquiditySources(parameters: parameters)
    }

    func fetchBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?] {
        async let local = try await fetchLocalBalance(for: chainAssets)
        async let remote = try await fetchRemoteBalance(for: chainAssets)

        let merged = try await local.merging(remote) { local, remote in remote ?? local }
        return merged
    }

    func fetchOkxChainAsset(nativeChainAsset: ChainAsset) async throws -> ChainAsset? {
        let chainAssets = try await assetFetching.fetchAssets(for: nativeChainAsset.chain, preferredDataSourceType: .combine)

        if nativeChainAsset.isUtility {
            return chainAssets.first { $0.isUtility }
        }

        return chainAssets.first { $0.asset.symbol.lowercased() == nativeChainAsset.asset.symbol.lowercased() }
    }
    
    func fetchFundsPermissionMode(swapFromChainAsset: ChainAsset, amount: String) async throws -> CrossChainFundsPermissionMode {
        guard let swapService = try? dependencyContainer.getEthereumSwapService(for: swapFromChainAsset) else {
            return .none
        }
        
        guard !swapFromChainAsset.asset.isUtility else {
            return .none
        }

        guard let amount = BigUInt(string: amount) else {
            return .none
        }

        guard let dexTokenApproveAddress = try await okxService.fetchAvailableChains(preferredDataSourceType: .combine).data?.first(where: { swapFromChainAsset.chain.chainId == "\($0.chainId)" })?.dexTokenApproveAddress else {
            throw CrossChainSwapConfirmInteractorError.invalidApproveTransactionResponse
        }
        let allowance = try await swapService.getAllowance(dexTokenApproveAddress: dexTokenApproveAddress, chainAsset: swapFromChainAsset)

        if allowance > 0, allowance < amount {
            return .revoke(dexTokenApproveAddress: dexTokenApproveAddress)
        }
        
        if allowance < amount {
            return .approve(dexTokenApproveAddress: dexTokenApproveAddress)
        }
        
        return .none
    }
}
