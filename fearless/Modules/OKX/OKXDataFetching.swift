import SSFModels
import BigInt

protocol OKXDataFetching {
    func fetchQuoteInfo(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> OKXQuoteInfo?

    func fetchTransactionData(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> CrossChainTx?
}
