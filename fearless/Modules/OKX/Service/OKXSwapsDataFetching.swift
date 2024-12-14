import SSFModels
import Web3

final class OKXCrossChainDataFetching {
    private let okxService: OKXDexAggregatorService
    private let wallet: MetaAccountModel

    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel
    ) {
        self.okxService = okxService
        self.wallet = wallet
    }
}

extension OKXCrossChainDataFetching: OKXDataFetching {
    func fetchQuoteInfo(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> OKXQuoteInfo? {
        let fromTokenAddress = sourceChainAsset.asset.currencyId ?? sourceChainAsset.asset.id
        let toTokenAddress = destinationChainAsset.asset.currencyId ?? destinationChainAsset.asset.id
        let quoteParameters = OKXDexCrossChainQuoteParameters(
            fromChainId: sourceChainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            sort: 1,
            slippage: "0.01",
            allowBridge: selectedDexIds?.compactMap { UInt32($0) }
        )

        let swap = try await okxService.fetchCrossChainQuote(parameters: quoteParameters).data?.first
        let feeString = swap?.routerList.first?.fromChainNetworkFee

        let fee = feeString.flatMap { BigUInt(string: $0) }

        return OKXQuoteInfo(fee: fee, swap: swap)
    }
}
