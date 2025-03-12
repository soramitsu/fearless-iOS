import SSFModels
import Web3
import SSFAccountManagment

enum OKXCrossChainDataFetchingError: Error {
    case noData
}

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
        selectedDexIds: [String]?,
        slippage: String
    ) async throws -> OKXQuoteInfo {
        let fromTokenAddress = sourceChainAsset.asset.currencyId ?? sourceChainAsset.asset.id
        let toTokenAddress = destinationChainAsset.asset.currencyId ?? destinationChainAsset.asset.id
        let quoteParameters = OKXDexCrossChainQuoteParameters(
            fromChainId: sourceChainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            sort: 0,
            slippage: slippage,
            allowBridge: selectedDexIds?.compactMap { UInt32($0) }
        )

        guard let swap = try await okxService.fetchCrossChainQuote(parameters: quoteParameters).data?.first else {
            throw OKXCrossChainDataFetchingError.noData
        }
        
        let feeString = swap.routerList.first?.fromChainNetworkFee
        let fee = feeString.flatMap { BigUInt(string: $0) }

        return OKXQuoteInfo(fee: fee, swap: swap)
    }

    func fetchTransactionData(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?,
        slippage: String
    ) async throws -> CrossChainTx? {
        guard let address = wallet.fetch(for: sourceChainAsset.chain.accountRequest())?.toAddress() else {
            throw ChainAccountFetchingError.accountNotExists
        }

        let fromTokenAddress = sourceChainAsset.asset.currencyId ?? sourceChainAsset.asset.id
        let toTokenAddress = destinationChainAsset.asset.currencyId ?? destinationChainAsset.asset.id
        let quoteParameters = OKXDexCrossChainBuildTxParameters(
            fromChainId: sourceChainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            sort: 0,
            slippage: slippage,
            userWalletAddress: address,
            referrerAddress: CrossChain.Constants.referrerAddress,
            feePercent: CrossChain.Constants.walletFeePercent,
            allowBridge: selectedDexIds?.compactMap { UInt32($0) }
        )

        let swap = try await okxService.fetchSwapInfo(parameters: quoteParameters).data?.first
        return swap
    }
}
