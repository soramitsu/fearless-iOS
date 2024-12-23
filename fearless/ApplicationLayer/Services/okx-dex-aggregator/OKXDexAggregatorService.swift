import Foundation
import SSFNetwork

enum OKXDexAggregatorServiceError: Error {
    case noCachedData
}

protocol OKXDexAggregatorService {
    func fetchAvailableChains(preferredDataSourceType: PreferredDataSourceType) async throws -> OKXResponse<OKXSupportedChain>
    func fetchAllTokens(parameters: OKXDexAllTokensRequestParameters, preferredDataSourceType: PreferredDataSourceType) async throws -> OKXResponse<OKXToken>
    func fetchLiquiditySources(parameters: OKXDexLiquiditySourceRequestParameters) async throws -> OKXResponse<OKXLiquiditySource>
    func fetchQuotes(parameters: OKXDexQuotesRequestParameters) async throws -> OKXResponse<OKXQuote>
    func fetchApproveTransactionInfo(parameters: OKXDexApproveRequestParameters) async throws -> OKXResponse<OKXApproveTransaction>
    func fetchSwapInfo(parameters: OKXDexSwapRequestParameters) async throws -> OKXResponse<OKXSwap>
    func fetchSwapInfo(parameters: OKXDexCrossChainBuildTxParameters) async throws -> OKXResponse<OKXCrossChainSwap>
    func fetchAvailableDestinationTokens(parameters: OKXDexCrossChainSupportedBridgeTokensPairsParameters) async throws -> OKXResponse<OKXAvailableDestination>
    func fetchCrossChainTransactionStatus(parameters: OKXDexCrossChainStatusParameters) async throws -> OKXResponse<OKXCrossChainTransactionStatus>
    func fetchCrossChainQuote(parameters: OKXDexCrossChainQuoteParameters) async throws -> OKXResponse<OKXCrossChainQuote>
    func fetchTransactionByHash(parameters: OKXWalletTransactionByHashParameters) async throws -> OKXResponse<OKXTransactionHistoryElement>
}

final class OKXDexAggregatorServiceImpl: OKXDexAggregatorService {
    private let networkWorker: NetworkWorker
    private let signer: RequestSigner

    init(networkWorker: NetworkWorker, signer: RequestSigner) {
        self.networkWorker = networkWorker
        self.signer = signer
    }

    func fetchAvailableChains(preferredDataSourceType: PreferredDataSourceType) async throws -> OKXResponse<OKXSupportedChain> {
        let request = RequestConfig(baseURL: ApplicationConfig.shared.okxDexAggregatorURL, method: .get, endpoint: "/api/v5/dex/aggregator/supported/chain", headers: nil, body: nil)
        request.signingType = .custom(signer: signer)
        var response: OKXResponse<OKXSupportedChain>

        switch preferredDataSourceType {
        case .cache:
            guard let cached: OKXResponse<OKXSupportedChain> = try await networkWorker.fetchCached(with: request) else {
                throw OKXDexAggregatorServiceError.noCachedData
            }

            response = cached
        case .remote:
            response = try await networkWorker.performRequest(with: request)
        case .combine:
            if let cached: OKXResponse<OKXSupportedChain> = try await networkWorker.fetchCached(with: request) {
                response = cached
            } else {
                response = try await networkWorker.performRequest(with: request)
            }
        }
        
        try validateResponseCode(response.code, msg: response.msg)

        return response
    }

    func fetchAllTokens(parameters: OKXDexAllTokensRequestParameters, preferredDataSourceType: PreferredDataSourceType) async throws -> OKXResponse<OKXToken> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "/api/v5/dex/aggregator/all-tokens",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)

        var response: OKXResponse<OKXToken>

        switch preferredDataSourceType {
        case .cache:
            guard let cached: OKXResponse<OKXToken> = try await networkWorker.fetchCached(with: request) else {
                throw OKXDexAggregatorServiceError.noCachedData
            }

            response = cached
        case .remote:
            response = try await networkWorker.performRequest(with: request)
        case .combine:
            if let cached: OKXResponse<OKXToken> = try await networkWorker.fetchCached(with: request) {
                response = cached
            } else {
                response = try await networkWorker.performRequest(with: request)
            }
        }

        try validateResponseCode(response.code, msg: response.msg)

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

        if let cached: OKXResponse<OKXLiquiditySource> = try await networkWorker.fetchCached(with: request) {
            return cached
        }

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXLiquiditySource> = try await networkWorker.performRequest(with: request)

        try validateResponseCode(response.code, msg: response.msg)

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

        try validateResponseCode(response.code, msg: response.msg)

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

        try validateResponseCode(response.code, msg: response.msg)

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

        try validateResponseCode(response.code, msg: response.msg)

        return response
    }

    func fetchSwapInfo(parameters: OKXDexCrossChainBuildTxParameters) async throws -> OKXResponse<OKXCrossChainSwap> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/cross-chain/build-tx",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXCrossChainSwap> = try await networkWorker.performRequest(with: request)

        try validateResponseCode(response.code, msg: response.msg)

        return response
    }

    func fetchAvailableDestinationTokens(parameters: OKXDexCrossChainSupportedBridgeTokensPairsParameters) async throws -> OKXResponse<OKXAvailableDestination> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/cross-chain/supported/bridge-tokens-pairs",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXAvailableDestination> = try await networkWorker.performRequest(with: request)

        try validateResponseCode(response.code, msg: response.msg)

        return response
    }

    func fetchCrossChainTransactionStatus(parameters: OKXDexCrossChainStatusParameters) async throws -> OKXResponse<OKXCrossChainTransactionStatus> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/cross-chain/status",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXCrossChainTransactionStatus> = try await networkWorker.performRequest(with: request)

        try validateResponseCode(response.code, msg: response.msg)

        return response
    }

    func fetchCrossChainQuote(parameters: OKXDexCrossChainQuoteParameters) async throws -> OKXResponse<OKXCrossChainQuote> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/dex/cross-chain/quote",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXCrossChainQuote> = try await networkWorker.performRequest(with: request)

        try validateResponseCode(response.code, msg: response.msg)

        return response
    }

    func fetchTransactionByHash(parameters: OKXWalletTransactionByHashParameters) async throws -> OKXResponse<OKXTransactionHistoryElement> {
        let request = RequestConfig(
            baseURL: ApplicationConfig.shared.okxDexAggregatorURL,
            method: .get,
            endpoint: "api/v5/wallet/post-transaction/transaction-detail-by-txhash",
            queryItems: parameters.urlParameters,
            headers: nil,
            body: nil
        )

        request.signingType = .custom(signer: signer)
        let response: OKXResponse<OKXTransactionHistoryElement> = try await networkWorker.performRequest(with: request)

        try validateResponseCode(response.code, msg: response.msg)

        return response
    }

    private func validateResponseCode(_ code: String, msg: String?) throws {
        guard code == "0" else {
            switch code {
            case OKXDexErrorCode.okxMinimumAmountErrorCode.rawValue:
                throw OKXDexError.minimumAmount(text: msg)
            case OKXDexErrorCode.okxMaximumAmountErrorCode.rawValue:
                throw OKXDexError.maximumAmount(text: msg)
            case OKXDexErrorCode.okxInsufficientLiquidity.rawValue:
                throw OKXDexError.insufficientLiquidity
            default:
                throw OKXDexError.unknown(text: msg)
            }
        }
    }
}
