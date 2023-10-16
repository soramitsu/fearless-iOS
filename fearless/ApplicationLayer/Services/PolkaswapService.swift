import Foundation
import RobinHood
import SSFModels
import BigInt

protocol PolkaswapService {
    func fetchQuotes(
        amount: BigUInt,
        fromChainAsset: ChainAsset,
        toChainAsset: ChainAsset
    ) async throws -> SwapValues?
}

final class PolkaswapServiceImpl: PolkaswapService {
    private let polkaswapOperationFactory: PolkaswapOperationFactoryProtocol
    private let settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>
    private let operationManager: OperationManagerProtocol

    init(
        polkaswapOperationFactory: PolkaswapOperationFactoryProtocol,
        settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>,
        operationManager: OperationManagerProtocol
    ) {
        self.polkaswapOperationFactory = polkaswapOperationFactory
        self.settingsRepository = settingsRepository
        self.operationManager = operationManager
    }

    // MARK: - PolkaswapService

    func fetchQuotes(
        amount: BigUInt,
        fromChainAsset: ChainAsset,
        toChainAsset: ChainAsset
    ) async throws -> SwapValues? {
        let (market, dexIds) = try await fetchPolkaswapSettings(fromChainAsset: fromChainAsset, toChainAsset: toChainAsset)
        let bestQuote = await fetchBestQuote(
            amount: amount,
            fromChainAsset: fromChainAsset,
            toChainAsset: toChainAsset,
            market: market,
            dexIds: dexIds
        )
        return bestQuote
    }

    // MARK: - Private methods

    private func fetchPolkaswapSettings(
        fromChainAsset: ChainAsset,
        toChainAsset: ChainAsset
    ) async throws -> (market: SwapMarketSourceProtocol?, dexIds: [UInt32]) {
        let operation = settingsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operationManager.enqueue(operations: [operation], in: .transient)

        return try await withUnsafeThrowingContinuation { continuation in
            operation.completionBlock = {
                do {
                    guard let settings = try operation.extractNoCancellableResultData().first else {
                        continuation.resume(throwing: ConvenienceError(error: "Settings operation canceled"))
                        return
                    }

                    let dexIds = settings.availableDexIds.map { $0.code }

                    let marketSource = SwapMarketSource(
                        fromAssetId: fromChainAsset.asset.currencyId,
                        toAssetId: toChainAsset.asset.currencyId,
                        remoteSettings: settings
                    )
                    marketSource?.didLoad([.smart])

                    let result = (marketSource, dexIds)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchBestQuote(
        amount: BigUInt,
        fromChainAsset: ChainAsset,
        toChainAsset: ChainAsset,
        market: SwapMarketSourceProtocol?,
        dexIds: [UInt32]
    ) async -> SwapValues? {
        await withTaskGroup(of: SwapValues?.self, returning: SwapValues?.self, body: { group in
            dexIds.forEach { dexId in
                group.addTask {
                    try? await self.fetchQuote(
                        amount: amount,
                        fromChainAsset: fromChainAsset,
                        toChainAsset: toChainAsset,
                        market: market,
                        dexId: dexId
                    )
                }
            }

            var swapValues: [SwapValues?] = []
            for await swapValue in group {
                swapValues.append(swapValue)
            }

            return swapValues
                .compactMap { $0 }
                .sorted(by: { BigUInt(string: $0.amount) ?? .zero > BigUInt(string: $1.amount) ?? .zero })
                .first
        })
    }

    private func fetchQuote(
        amount: BigUInt,
        fromChainAsset: ChainAsset,
        toChainAsset: ChainAsset,
        market: SwapMarketSourceProtocol?,
        dexId: UInt32
    ) async throws -> SwapValues {
        guard
            let marketSourcer = market,
            let fromAssetId = fromChainAsset.asset.currencyId,
            let toAssetId = toChainAsset.asset.currencyId
        else {
            throw ConvenienceError(error: "Missing required params Polkaswap Service")
        }

        let amountString = String(amount)

        let quoteParams = PolkaswapQuoteParams(
            fromAssetId: fromAssetId,
            toAssetId: toAssetId,
            amount: amountString,
            swapVariant: .desiredInput,
            liquiditySources: marketSourcer.getRemoteMarketSources(),
            filterMode: LiquiditySourceType.smart.filterMode
        )

        let quotesOperation = polkaswapOperationFactory
            .createPolkaswapQuoteOperation(dexId: dexId, params: quoteParams)
        operationManager.enqueue(operations: [quotesOperation], in: .transient)

        return try await withUnsafeThrowingContinuation { continuation in
            quotesOperation.completionBlock = {
                do {
                    let result = try quotesOperation.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
