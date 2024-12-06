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

final class CrossChainSwapSetupInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainSwapSetupInteractorOutput?
    private let wallet: MetaAccountModel
    private let okxService: OKXDexAggregatorService
    private let balanceFetching: EthereumRemoteBalanceFetching
    private let accountInfoFetchingProvider: AccountInfoFetching
    private let dependencyContainer: CrossChainDependencyContainer

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
        self.dependencyContainer = dependencyContainer
    }

    private func getCrossChainQuotes(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String
    ) async throws -> [CrossChainSwap]? {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            throw CrossChainSwapSetupInteractorError.accountNotFound
        }

        let fromTokenAddress = chainAsset.asset.currencyId ?? chainAsset.asset.id
        let toTokenAddress = destinationChainAsset.asset.currencyId ?? destinationChainAsset.asset.id
        let quoteParameters = OKXDexCrossChainQuoteParameters(
            fromChainId: chainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            sort: 0,
            slippage: "0.01"
        )

        let quotes = try await okxService.fetchCrossChainQuote(parameters: quoteParameters)
        return quotes.data
    }

    private func getSameChainQuotes(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> [CrossChainSwap]? {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            throw CrossChainSwapSetupInteractorError.accountNotFound
        }
        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: chainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters)

        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)
        let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters)
        let dexIds = (selectedDexIds?.joined(by: ", ")).map { String($0) }

        guard
            let fromTokenAddress = fromTokens.data?.first(where: { $0.tokenSymbol.lowercased() == chainAsset.asset.symbol.lowercased() })?.tokenContractAddress,
            let toTokenAddress = toTokens.data?.first(where: { $0.tokenSymbol.lowercased() == destinationChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let parameters = OKXDexSwapRequestParameters(
            chainId: chainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            slippage: "0.01",
            userWalletAddress: address,
            dexIds: dexIds
        )

        let quotes = try await okxService.fetchSwapInfo(parameters: parameters)
        return quotes.data
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
    func fetchSwapSetupInfo(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> OKXSwapSetupInfo? {
        let okxCase = OKXCase(fromChainAsset: chainAsset, toChainAsset: destinationChainAsset)
        let fetcher = try dependencyContainer.getOkxDataFetcher(for: okxCase)

        return try await fetcher.fetchSwapSetupInfo(
            sourceChainAsset: chainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            selectedDexIds: selectedDexIds
        )
    }

    func setup(with output: CrossChainSwapSetupInteractorOutput) {
        self.output = output
    }

    func getQuotes(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> [CrossChainSwap]? {
        if chainAsset.chain.chainId == destinationChainAsset.chain.chainId {
            return try await getSameChainQuotes(
                chainAsset: chainAsset,
                destinationChainAsset: destinationChainAsset,
                amount: amount,
                selectedDexIds: selectedDexIds
            )
        } else {
            return try await getCrossChainQuotes(
                chainAsset: chainAsset,
                destinationChainAsset: destinationChainAsset,
                amount: amount
            )
        }
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

    func fetchQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount: String) async throws -> [OKXDexQuote]? {
        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: chainAsset.chain.chainId)
        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)

        async let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters)
        async let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters)

        guard
            let fromTokenAddress = try await fromTokens.data?.first(where: { $0.tokenSymbol.lowercased() == chainAsset.asset.symbol.lowercased() })?.tokenContractAddress,
            let toTokenAddress = try await toTokens.data?.first(where: { $0.tokenSymbol.lowercased() == destinationChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let quotesParameters = OKXDexQuotesRequestParameters(chainId: chainAsset.chain.chainId, amount: amount, fromTokenAddress: fromTokenAddress, toTokenAddress: toTokenAddress)
        let quotes = try await okxService.fetchQuotes(parameters: quotesParameters)
        return quotes.data?.first?.quoteCompareList
    }
}
