import Foundation
import SSFNetwork

protocol OKXDexAggregatorService {
    func fetchAvailableChains() async throws -> OKXResponse<OKXSupportedChain>
    func fetchAllTokens(parameters: OKXDexAllTokensRequestParameters) async throws -> OKXResponse<OKXToken>
    func fetchLiquiditySources(parameters: OKXDexLiquiditySourceRequestParameters) async throws -> OKXResponse<OKXLiquiditySource>
    func fetchQuotes(parameters: OKXDexQuotesRequestParameters) async throws -> OKXResponse<OKXQuote>
    func fetchSwapInfo(parameters: OKXDexSwapRequestParameters) async throws -> OKXResponse<OKXSwap>
    func fetchApproveTransactionInfo(parameters: OKXDexApproveRequestParameters) async throws -> OKXResponse<OKXApproveTransaction>
}

protocol OKXDexAggregatorConfigSource {
    var okxDexAggregatorURL: URL { get }
}

extension ApplicationConfig: OKXDexAggregatorConfigSource {}

final class OKXDexAggregatorServiceImpl: OKXDexAggregatorService {
    private let networkWorker: NetworkWorkerDefault
    private let signer: RequestSigner
    private let configSource: OKXDexAggregatorConfigSource

    init(
        networkWorker: NetworkWorkerDefault,
        signer: RequestSigner,
        configSource: OKXDexAggregatorConfigSource = ApplicationConfig.shared
    ) {
        self.networkWorker = networkWorker
        self.signer = signer
        self.configSource = configSource
    }

    func fetchAvailableChains() async throws -> OKXResponse<OKXSupportedChain> {
        let request = makeGetRequest(endpoint: "/api/v5/dex/aggregator/supported/chain")
        let response: OKXResponse<OKXSupportedChain> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchAllTokens(parameters: OKXDexAllTokensRequestParameters) async throws -> OKXResponse<OKXToken> {
        let request = makeGetRequest(
            endpoint: "/api/v5/dex/aggregator/all-tokens",
            queryItems: parameters.urlParameters
        )
        let response: OKXResponse<OKXToken> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchLiquiditySources(parameters: OKXDexLiquiditySourceRequestParameters) async throws -> OKXResponse<OKXLiquiditySource> {
        let request = makeGetRequest(
            endpoint: "api/v5/dex/aggregator/get-liquidity",
            queryItems: parameters.urlParameters
        )
        let response: OKXResponse<OKXLiquiditySource> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchQuotes(parameters: OKXDexQuotesRequestParameters) async throws -> OKXResponse<OKXQuote> {
        let request = makeGetRequest(
            endpoint: "api/v5/dex/aggregator/quote",
            queryItems: parameters.urlParameters
        )
        let response: OKXResponse<OKXQuote> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchSwapInfo(parameters: OKXDexSwapRequestParameters) async throws -> OKXResponse<OKXSwap> {
        let request = makeGetRequest(
            endpoint: "api/v5/dex/aggregator/swap",
            queryItems: parameters.urlParameters
        )
        let response: OKXResponse<OKXSwap> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchApproveTransactionInfo(parameters: OKXDexApproveRequestParameters) async throws -> OKXResponse<OKXApproveTransaction> {
        let request = makeGetRequest(
            endpoint: "api/v5/dex/aggregator/approve-transaction",
            queryItems: parameters.urlParameters
        )
        let response: OKXResponse<OKXApproveTransaction> = try await networkWorker.performRequest(with: request)
        return response
    }

    private func makeGetRequest(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil
    ) -> RequestConfig {
        let request = RequestConfig(
            baseURL: configSource.okxDexAggregatorURL,
            method: .get,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: nil,
            body: nil
        )
        request.signingType = .custom(signer: signer)
        return request
    }
}
