import Foundation
#if canImport(FearlessKeys)
    import FearlessKeys
#endif

protocol AlchemyHistoryFetching {
    func fetchTransactionHistory(request: AlchemyHistoryRequest, chainId: String) async throws -> AlchemyHistory
}

enum AlchemyHistoryError: LocalizedError {
    case unsupportedChain, invalidConfiguration, invalidResponse, invalidCursor

    var errorDescription: String? {
        "Transaction history is temporarily unavailable. Please try again."
    }
}

enum AlchemyHistoryNetwork {
    static func identifier(chainId: String) -> String? {
        switch chainId {
        case "1": return "eth-mainnet"
        case "56": return "bnb-mainnet"
        case "137": return "polygon-mainnet"
        case "10": return "opt-mainnet"
        case "42161": return "arb-mainnet"
        default: return nil
        }
    }

    static func url(chainId: String, apiKey: String) throws -> URL {
        guard let network = identifier(chainId: chainId) else {
            throw AlchemyHistoryError.unsupportedChain
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard !apiKey.isEmpty, apiKey.unicodeScalars.allSatisfy(allowed.contains),
              let url = URL(string: "https://\(network).g.alchemy.com/v2/\(apiKey)") else {
            throw AlchemyHistoryError.invalidConfiguration
        }
        return url
    }
}

final class AlchemyService: AlchemyHistoryFetching {
    private let session: URLSession
    private let apiKey: String

    init(session: URLSession = .shared, apiKey: String? = nil) {
        self.session = session
        #if DEBUG
            self.apiKey = apiKey ?? ThirdPartyServicesApiKeysDebug.alchemyApiKey
        #else
            self.apiKey = apiKey ?? ThirdPartyServicesApiKeys.alchemyApiKey
        #endif
    }

    func fetchTransactionHistory(request: AlchemyHistoryRequest, chainId: String) async throws -> AlchemyHistory {
        struct Body: Encodable {
            let jsonrpc = "2.0"
            let id = 1
            let method = "alchemy_getAssetTransfers"
            let params: [AlchemyHistoryRequest]
        }
        var networkRequest = URLRequest(url: try AlchemyHistoryNetwork.url(chainId: chainId, apiKey: apiKey))
        networkRequest.httpMethod = "POST"
        networkRequest.timeoutInterval = 30
        networkRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        networkRequest.httpBody = try JSONEncoder().encode(Body(params: [request]))
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: networkRequest)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw AlchemyHistoryError.invalidResponse
        }
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw AlchemyHistoryError.invalidResponse
        }
        // Provider error payloads must surface as failures, never an empty wallet
        // history. Do not propagate a provider message containing a key or URL.
        guard let result = try? JSONDecoder().decode(AlchemyResponse<AlchemyHistory>.self, from: data),
              result.jsonrpc == "2.0", result.id == 1 else {
            throw AlchemyHistoryError.invalidResponse
        }
        return result.result
    }
}
