import UIKit
import SSFModels

protocol BridgeListInteractorOutput: AnyObject {}

final class BridgeListInteractor {
    // MARK: - Private properties

    private weak var output: BridgeListInteractorOutput?
    private let okxService: OKXDexAggregatorService
    private let sourceChainAsset: ChainAsset
    private let destinationChainAsset: ChainAsset
    private let amount: String
    private let wallet: MetaAccountModel
    private let assetFetching: MultichainAssetFetching
    private let okxSwapService: OKXEthereumSwapService

    init(
        okxService: OKXDexAggregatorService,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        assetFetching: MultichainAssetFetching,
        okxSwapService: OKXEthereumSwapService
    ) {
        self.okxService = okxService
        self.sourceChainAsset = sourceChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.wallet = wallet
        self.amount = amount
        self.assetFetching = assetFetching
        self.okxSwapService = okxSwapService
    }
}

// MARK: - BridgeListInteractorInput

extension BridgeListInteractor: BridgeListInteractorInput {
    func setup(with output: BridgeListInteractorOutput) {
        self.output = output
    }

    func getCrossChainQuotes(sort: UInt8) async throws -> [OKXCrossChainQuote]? {
        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: sourceChainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters)

        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)
        let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters)

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

    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset] {
        try await assetFetching.fetchAssets(for: chain)
    }

    func fetchFee(swap: OKXCrossChainSwap?) {
        guard let swap else {
            return
        }

//        Task {
//            do {
//                let fee = try await okxSwapService.estimateFee(swap: swap)
//                print("fee: ", fee)
//            } catch {
//                print("fee: error ", error)
//            }
//        }
    }
}
