import SSFModels
import BigInt

protocol OKXDataFetching {
    func fetchSwapSetupInfo(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> OKXSwapSetupInfo?
}
