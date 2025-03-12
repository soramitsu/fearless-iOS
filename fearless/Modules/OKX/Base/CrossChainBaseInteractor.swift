import SSFModels
import BigInt

protocol CrossChainBaseInteractorInput {
    func fetchSwapSetupInfo(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        slippage: String,
        selectedDexIds: [String]?
    ) async throws -> OKXQuoteInfo

    func fetchTransactionData(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        slippage: String,
        selectedDexIds: [String]?
    ) async throws -> CrossChainTx?
    
    func estimateFee(
        for quote: CrossChainSwap,
        chainAsset: ChainAsset
    ) async throws -> BigUInt?
    
    func estimateFee(
        for swap: CrossChainTx,
        chainAsset: ChainAsset
    ) async throws -> BigUInt?
    
    func fetchChainAssets(for chain: ChainModel) async throws -> [ChainAsset]
}

class CrossChainBaseInteractor: CrossChainBaseInteractorInput {
    let dependencyContainer: CrossChainDependencyContainer
    let assetFetching: MultichainAssetFetching

    init(
        dependencyContainer: CrossChainDependencyContainer,
        assetFetching: MultichainAssetFetching
    ) {
        self.dependencyContainer = dependencyContainer
        self.assetFetching = assetFetching
    }
    
    func fetchChainAssets(for chain: ChainModel) async throws -> [ChainAsset] {
        try await assetFetching.fetchAssets(for: chain, preferredDataSourceType: .combine)
    }

    func fetchSwapSetupInfo(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        slippage: String,
        selectedDexIds: [String]?
    ) async throws -> OKXQuoteInfo {
        let okxCase = OKXCase(fromChainAsset: chainAsset, toChainAsset: destinationChainAsset)
        let fetcher = try dependencyContainer.getOkxDataFetcher(for: okxCase)

        return try await fetcher.fetchQuoteInfo(
            sourceChainAsset: chainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            selectedDexIds: selectedDexIds,
            slippage: slippage
        )
    }

    func fetchTransactionData(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        slippage: String,
        selectedDexIds: [String]?
    ) async throws -> CrossChainTx? {
        let okxCase = OKXCase(fromChainAsset: chainAsset, toChainAsset: destinationChainAsset)
        let fetcher = try dependencyContainer.getOkxDataFetcher(for: okxCase)

        return try await fetcher.fetchTransactionData(
            sourceChainAsset: chainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            selectedDexIds: selectedDexIds,
            slippage: slippage
        )
    }
    
    func estimateFee(
        for quote: any CrossChainSwap,
        chainAsset: ChainAsset
    ) async throws -> BigUInt? {
        let service = dependencyContainer.getEthereumSwapService(for: chainAsset)
        return try await service?.estimateFee(quote: quote)
    }
    
    func estimateFee(
        for swap: CrossChainTx,
        chainAsset: ChainAsset
    ) async throws -> BigUInt? {
        let service = dependencyContainer.getEthereumSwapService(for: chainAsset)
        return try await service?.estimateFee(swap: swap)
    }
}
