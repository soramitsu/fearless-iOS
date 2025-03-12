import UIKit
import SSFModels
import BigInt

enum CrossChainSwapSetupInteractorError: Error {
    case cannotFindTokenAddress
    case accountNotFound
    case connectionUnavailable
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
        
        super.init(
            dependencyContainer: dependencyContainer,
            assetFetching: assetFetching
        )
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

        return chainAssets.first { $0.asset.id.lowercased() == nativeChainAsset.asset.id.lowercased() }
    }
    
    func fetchDexTokenApproveAddress(chainAsset: ChainAsset) async throws -> String? {
        return try await okxService.fetchAvailableChains(preferredDataSourceType: .combine).data?.first(where: { chainAsset.chain.chainId == "\($0.chainId)" })?.dexTokenApproveAddress
    }
    
    func fetchAllowance(swapFromChainAsset: ChainAsset, dexTokenApproveAddress: String) async throws -> BigUInt? {
        guard let swapService = dependencyContainer.getEthereumSwapService(for: swapFromChainAsset) else {
            throw CrossChainSwapSetupInteractorError.connectionUnavailable
        }
        
        guard !swapFromChainAsset.asset.isUtility else {
            return .zero
        }

        let allowance = try await swapService.getAllowance(dexTokenApproveAddress: dexTokenApproveAddress, chainAsset: swapFromChainAsset)
        return allowance
    }
}
