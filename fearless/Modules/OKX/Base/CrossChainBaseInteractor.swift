import SSFModels

protocol CrossChainBaseInteractorInput {
    func fetchSwapSetupInfo(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> OKXQuoteInfo?

    func fetchTransactionData(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> CrossChainTx?
}

class CrossChainBaseInteractor: CrossChainBaseInteractorInput {
    let dependencyContainer: CrossChainDependencyContainer

    init(dependencyContainer: CrossChainDependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }

    func fetchSwapSetupInfo(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> OKXQuoteInfo? {
        let okxCase = OKXCase(fromChainAsset: chainAsset, toChainAsset: destinationChainAsset)
        let fetcher = try dependencyContainer.getOkxDataFetcher(for: okxCase)

        return try await fetcher.fetchQuoteInfo(
            sourceChainAsset: chainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            selectedDexIds: selectedDexIds
        )
    }

    func fetchTransactionData(
        chainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        selectedDexIds: [String]?
    ) async throws -> CrossChainTx? {
        let okxCase = OKXCase(fromChainAsset: chainAsset, toChainAsset: destinationChainAsset)
        let fetcher = try dependencyContainer.getOkxDataFetcher(for: okxCase)

        return try await fetcher.fetchTransactionData(
            sourceChainAsset: chainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            selectedDexIds: selectedDexIds
        )
    }
}
