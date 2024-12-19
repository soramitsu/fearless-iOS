import UIKit
import SSFModels

protocol DexListInteractorOutput: AnyObject {}

final class DexListInteractor {
    // MARK: - Private properties

    private weak var output: DexListInteractorOutput?
    private let okxService: OKXDexAggregatorService
    private let sourceChainAsset: ChainAsset
    private let destinationChainAsset: ChainAsset
    private let amount: String
    private let wallet: MetaAccountModel

    init(
        okxService: OKXDexAggregatorService,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel
    ) {
        self.okxService = okxService
        self.sourceChainAsset = sourceChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.wallet = wallet
        self.amount = amount
    }
}

// MARK: - DexListInteractorInput

extension DexListInteractor: DexListInteractorInput {
    func setup(with output: DexListInteractorOutput) {
        self.output = output
    }

    func getCrossChainQuotes(sort: UInt8) async throws -> [OKXCrossChainQuote]? {
        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: sourceChainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters, preferredDataSourceType: .combine)

        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)
        let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters, preferredDataSourceType: .combine)

        guard
            let fromTokenAddress = fromTokens.data?.first(where: { $0.tokenSymbol.lowercased() == sourceChainAsset.asset.symbol.lowercased() })?.tokenContractAddress,
            let toTokenAddress = toTokens.data?.first(where: { $0.tokenSymbol.lowercased() == destinationChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let quoteParameters = OKXDexCrossChainQuoteParameters(
            fromChainId: sourceChainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            sort: sort,
            slippage: "0.01"
        )

        let quotes = try await okxService.fetchCrossChainQuote(parameters: quoteParameters)
        return quotes.data
    }

    func getSameChainQuotes() async throws -> [OKXDexQuote]? {
        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: sourceChainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters, preferredDataSourceType: .combine)

        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)
        let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters, preferredDataSourceType: .combine)

        guard
            let fromTokenAddress = fromTokens.data?.first(where: { $0.tokenSymbol.lowercased() == sourceChainAsset.asset.symbol.lowercased() })?.tokenContractAddress,
            let toTokenAddress = toTokens.data?.first(where: { $0.tokenSymbol.lowercased() == destinationChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let quotesParameters = OKXDexQuotesRequestParameters(chainId: sourceChainAsset.chain.chainId, amount: amount, fromTokenAddress: fromTokenAddress, toTokenAddress: toTokenAddress)
        let quotes = try await okxService.fetchQuotes(parameters: quotesParameters)
        return quotes.data?.first?.quoteCompareList
    }

    func getLiquiditySources() async throws -> [OKXLiquiditySource]? {
        let parameters = OKXDexLiquiditySourceRequestParameters(chainId: sourceChainAsset.chain.chainId)
        let liquiditySources = try await okxService.fetchLiquiditySources(parameters: parameters)
        return liquiditySources.data
    }
}
