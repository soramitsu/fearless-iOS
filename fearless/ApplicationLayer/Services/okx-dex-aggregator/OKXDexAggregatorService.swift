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

final class OKXDexAggregatorServiceImpl: OKXDexAggregatorService {
    private let networkWorker: NetworkWorker
    private let signer: RequestSigner

    init(networkWorker: NetworkWorker, signer: RequestSigner) {
        self.networkWorker = networkWorker
        self.signer = signer
    }

    func fetchAvailableChains() async throws -> OKXResponse<OKXSupportedChain> {
        let request = RequestConfig(baseURL: ApplicationConfig.shared.okxDexAggregatorURL, method: .get, endpoint: "/api/v5/dex/aggregator/supported/chain", headers: nil, body: nil)
        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXSupportedChain> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchAllTokens(parameters: OKXDexAllTokensRequestParameters) async throws -> OKXResponse<OKXToken> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "/api/v5/dex/aggregator/all-tokens",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXToken> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchLiquiditySources(parameters: OKXDexLiquiditySourceRequestParameters) async throws -> OKXResponse<OKXLiquiditySource> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/aggregator/get-liquidity",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXLiquiditySource> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchQuotes(parameters: OKXDexQuotesRequestParameters) async throws -> OKXResponse<OKXQuote> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/aggregator/quote",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXQuote> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchSwapInfo(parameters: OKXDexSwapRequestParameters) async throws -> OKXResponse<OKXSwap> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/aggregator/swap",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXSwap> = try await networkWorker.performRequest(with: request)
        return response
    }

    func fetchApproveTransactionInfo(parameters: OKXDexApproveRequestParameters) async throws -> OKXResponse<OKXApproveTransaction> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/aggregator/approve-transaction",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXApproveTransaction> = try await networkWorker.performRequest(with: request)
        return response
    }
}
