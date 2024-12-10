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

    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel,
        balanceFetching: EthereumRemoteBalanceFetching,
        accountInfoFetchingProvider: AccountInfoFetching,
        dependencyContainer: CrossChainDependencyContainer
    ) {
        self.okxService = okxService
        self.wallet = wallet
        self.balanceFetching = balanceFetching
        self.accountInfoFetchingProvider = accountInfoFetchingProvider

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
}
