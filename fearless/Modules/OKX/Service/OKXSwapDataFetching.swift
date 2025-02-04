import SSFModels
import Web3

final class OKXSwapsDataFetching {
    private let okxService: OKXDexAggregatorService
    private let wallet: MetaAccountModel
    private let ethereumService: EthereumService

    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel,
        ethereumService: EthereumService
    ) {
        self.okxService = okxService
        self.wallet = wallet
        self.ethereumService = ethereumService
    }
}

extension OKXSwapsDataFetching: OKXDataFetching {
    func fetchQuoteInfo(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?,
        slippage: String
    ) async throws -> OKXQuoteInfo? {
        guard let address = wallet.fetch(for: sourceChainAsset.chain.accountRequest())?.toAddress() else {
            throw CrossChainSwapSetupInteractorError.accountNotFound
        }

        let dexIds = (selectedDexIds?.joined(by: ", ")).map { String($0) }

        guard
            let fromTokenAddress = sourceChainAsset.asset.currencyId,
            let toTokenAddress = destinationChainAsset.asset.currencyId
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let parameters = OKXDexSwapRequestParameters(
            chainId: sourceChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            slippage: slippage,
            userWalletAddress: address,
            dexIds: dexIds
        )

        let swap = try await okxService.fetchSwapInfo(parameters: parameters).data?.first
        let gas = swap?.routerResult.estimateGasFee
        let gasPrice = try await ethereumService.queryGasPrice()
        let fee = gas.flatMap { BigUInt(string: $0).or(.zero) * gasPrice.quantity }

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
            throw CrossChainSwapSetupInteractorError.accountNotFound
        }

        let dexIds = (selectedDexIds?.joined(by: ", ")).map { String($0) }

        guard
            let fromTokenAddress = sourceChainAsset.asset.currencyId,
            let toTokenAddress = destinationChainAsset.asset.currencyId
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let parameters = OKXDexSwapRequestParameters(
            chainId: sourceChainAsset.chain.chainId,
            amount: amount,
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            slippage: slippage,
            userWalletAddress: address,
            dexIds: dexIds
        )

        let swap = try await okxService.fetchSwapInfo(parameters: parameters).data?.first
        return swap
    }
}
