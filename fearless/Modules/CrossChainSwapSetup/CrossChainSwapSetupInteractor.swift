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

    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel,
        balanceFetching: EthereumRemoteBalanceFetching
    ) {
        self.okxService = okxService
        self.wallet = wallet
        self.balanceFetching = balanceFetching
    }

    private func getCrossChainQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount: String) async throws -> [CrossChainSwap]? {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            throw CrossChainSwapSetupInteractorError.accountNotFound
        }

        let parameters = OKXDexCrossChainBuildTxParameters(
            fromChainId: chainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: chainAsset.asset.id,
            toTokenAddress: destinationChainAsset.asset.id,
            sort: 0,
            slippage: "0.01",
            userWalletAddress: address
        )

        let quotes = try await okxService.fetchSwapInfo(parameters: parameters)
        return quotes.data
    }

    private func getSameChainQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount: String, selectedDexIds: [String]?) async throws -> [CrossChainSwap]? {
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

        let quotesParameters = OKXDexQuotesRequestParameters(chainId: chainAsset.chain.chainId, amount: amount, fromTokenAddress: fromTokenAddress, toTokenAddress: toTokenAddress)

        let lsParameters = OKXDexLiquiditySourceRequestParameters(chainId: chainAsset.chain.chainId)
        let quotes = try await okxService.fetchSwapInfo(parameters: parameters)
        return quotes.data
    }
}

// MARK: - CrossChainSwapSetupInteractorInput

extension CrossChainSwapSetupInteractor: CrossChainSwapSetupInteractorInput {
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

    func subscribeOnBalance(for chainAssets: [ChainAsset]) {
        balanceFetching.fetch(for: chainAssets, wallet: wallet) { [weak self] accountInfoByChainAsset in
            accountInfoByChainAsset.forEach {
                self?.output?.didReceiveAccountInfo(result: .success($0.value), for: $0.key)
            }
        }
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
