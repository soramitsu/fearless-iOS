import Foundation

protocol SolanaRpcClientProtocol {
    func latestBlockhash(commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> SolanaLatestBlockhashResponse
    func feeForMessage(_ messageBase64: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> SolanaFeeForMessageResponse
    func minimumBalanceForRentExemption(dataLength: Int, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64
    func accountExists(address: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Bool
    func simulateTransaction(_ transactionBase64: String, options: SolanaSimulationOptions, rpcURL: String?) async throws -> SolanaSimulationResponse
    func sendRawTransaction(_ transactionBase64: String, options: SolanaBroadcastOptions, rpcURL: String?) async throws -> String
}

final class SolanaRpcClient: SolanaRpcClientProtocol {
    private let transport: UniversalWalletHTTPTransport
    private let defaultRPCURL: String
    private var nextId: Int64 = 1

    init(
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        defaultRPCURL: String = UniversalWalletRegistry.solanaMainnetRPCURL.absoluteString
    ) throws {
        _ = try SolanaRpcRoutes.normalizeRPCURL(defaultRPCURL)
        self.transport = transport
        self.defaultRPCURL = defaultRPCURL
    }

    func latestBlockhash(
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> SolanaLatestBlockhashResponse {
        try await request(
            method: "getLatestBlockhash",
            params: [["commitment": commitment.rawValue]],
            rpcURL: rpcURL,
            normalize: normalizeLatestBlockhashResponse
        )
    }

    func feeForMessage(
        _ messageBase64: String,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> SolanaFeeForMessageResponse {
        try await request(
            method: "getFeeForMessage",
            params: [
                try SolanaRpcRoutes.normalizeTransactionBase64(messageBase64),
                ["commitment": commitment.rawValue]
            ],
            rpcURL: rpcURL,
            normalize: normalizeFeeForMessageResponse
        )
    }

    func minimumBalanceForRentExemption(
        dataLength: Int,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> Int64 {
        try await request(
            method: "getMinimumBalanceForRentExemption",
            params: [
                try SolanaRpcRoutes.normalizeDataLength(dataLength),
                ["commitment": commitment.rawValue]
            ],
            rpcURL: rpcURL
        ) { value in
            try Self.requireUnsignedInt64(value, error: .invalidRentResponse)
        }
    }

    func accountExists(
        address: String,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> Bool {
        try await request(
            method: "getAccountInfo",
            params: [
                try SolanaRpcRoutes.normalizePublicKey(address),
                [
                    "commitment": commitment.rawValue,
                    "encoding": "base64"
                ]
            ],
            rpcURL: rpcURL,
            normalize: normalizeAccountInfoExists
        )
    }

    func simulateTransaction(
        _ transactionBase64: String,
        options: SolanaSimulationOptions = SolanaSimulationOptions(),
        rpcURL: String? = nil
    ) async throws -> SolanaSimulationResponse {
        if options.sigVerify, options.replaceRecentBlockhash {
            throw SolanaRpcClientError.invalidSimulationOptions
        }

        return try await request(
            method: "simulateTransaction",
            params: [
                try SolanaRpcRoutes.normalizeTransactionBase64(transactionBase64),
                [
                    "commitment": options.commitment.rawValue,
                    "encoding": "base64",
                    "replaceRecentBlockhash": options.replaceRecentBlockhash,
                    "sigVerify": options.sigVerify
                ]
            ],
            rpcURL: rpcURL,
            normalize: normalizeSimulationResponse
        )
    }

    func sendRawTransaction(
        _ transactionBase64: String,
        options: SolanaBroadcastOptions = SolanaBroadcastOptions(),
        rpcURL: String? = nil
    ) async throws -> String {
        if let maxRetries = options.maxRetries, !(0 ... 10).contains(maxRetries) {
            throw SolanaRpcClientError.invalidMaxRetries
        }

        var rpcOptions: [String: Any] = [
            "encoding": "base64",
            "preflightCommitment": options.preflightCommitment.rawValue,
            "skipPreflight": options.skipPreflight
        ]
        if let maxRetries = options.maxRetries {
            rpcOptions["maxRetries"] = maxRetries
        }

        return try await request(
            method: "sendTransaction",
            params: [
                try SolanaRpcRoutes.normalizeTransactionBase64(transactionBase64),
                rpcOptions
            ],
            rpcURL: rpcURL,
            normalize: normalizeSignature
        )
    }

    private func request<T>(
        method: String,
        params: [Any],
        rpcURL: String?,
        normalize: (Any) throws -> T
    ) async throws -> T {
        let id = nextId
        nextId += 1
        let url = try URL(string: SolanaRpcRoutes.normalizeRPCURL(rpcURL ?? defaultRPCURL)).orThrow(.invalidRPCURL)
        let body: [String: Any] = [
            "id": id,
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            data = try await transport.perform(request)
        } catch let UniversalWalletHTTPTransportError.httpStatusCode(status, _) {
            throw SolanaRpcClientError.httpStatusCode(status)
        }

        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SolanaRpcClientError.invalidRPCResponse
        }
        guard let object = json as? [String: Any],
              Self.jsonRpcVersion(object["jsonrpc"]) == "2.0",
              Self.int64(object["id"]) == id else {
            throw SolanaRpcClientError.invalidRPCResponse
        }
        if let error = object["error"], !(error is NSNull) {
            throw SolanaRpcClientError.rpcError(Self.normalizeRPCError(error))
        }
        guard let result = object["result"] else {
            throw SolanaRpcClientError.invalidRPCResponse
        }

        return try normalize(result)
    }

    private func normalizeLatestBlockhashResponse(_ value: Any) throws -> SolanaLatestBlockhashResponse {
        guard let object = value as? [String: Any] else {
            throw SolanaRpcClientError.invalidBlockhashResponse
        }
        return SolanaLatestBlockhashResponse(
            context: try Self.normalizeContext(object["context"], error: .invalidBlockhashResponse),
            value: try Self.normalizeLatestBlockhash(object["value"], error: .invalidBlockhashResponse)
        )
    }

    private func normalizeFeeForMessageResponse(_ value: Any) throws -> SolanaFeeForMessageResponse {
        guard let object = value as? [String: Any] else {
            throw SolanaRpcClientError.invalidFeeResponse
        }
        let fee = Self.isJSONNull(object["value"])
            ? nil
            : try Self.requireUnsignedInt64(object["value"], error: .invalidFeeResponse)

        return SolanaFeeForMessageResponse(
            context: try Self.normalizeContext(object["context"], error: .invalidFeeResponse),
            value: fee
        )
    }

    private func normalizeSimulationResponse(_ value: Any) throws -> SolanaSimulationResponse {
        guard let object = value as? [String: Any],
              let simulationValue = object["value"] as? [String: Any] else {
            throw SolanaRpcClientError.invalidSimulationResponse
        }
        let logs: [String]?
        if Self.isJSONNull(simulationValue["logs"]) || simulationValue["logs"] == nil {
            logs = nil
        } else if let values = simulationValue["logs"] as? [String] {
            logs = values
        } else {
            throw SolanaRpcClientError.invalidSimulationResponse
        }
        let unitsConsumed = Self.isJSONNull(simulationValue["unitsConsumed"]) || simulationValue["unitsConsumed"] == nil
            ? nil
            : try Self.requireUnsignedInt64(simulationValue["unitsConsumed"], error: .invalidSimulationResponse)
        let replacementBlockhash = Self.isJSONNull(simulationValue["replacementBlockhash"]) || simulationValue["replacementBlockhash"] == nil
            ? nil
            : try Self.normalizeLatestBlockhash(simulationValue["replacementBlockhash"], error: .invalidSimulationResponse)
        let errorJSON: String?
        if let errorValue = simulationValue["err"], !Self.isJSONNull(errorValue) {
            errorJSON = Self.jsonString(errorValue)
        } else {
            errorJSON = nil
        }

        return SolanaSimulationResponse(
            context: try Self.normalizeContext(object["context"], error: .invalidSimulationResponse),
            value: SolanaSimulationValue(
                errorJSON: errorJSON,
                logs: logs,
                replacementBlockhash: replacementBlockhash,
                unitsConsumed: unitsConsumed
            )
        )
    }

    private func normalizeSignature(_ value: Any) throws -> String {
        guard let signature = value as? String,
              Self.matches(signature, #"^[1-9A-HJ-NP-Za-km-z]{64,128}$"#) else {
            throw SolanaRpcClientError.invalidSignatureResponse
        }

        return signature
    }

    private static func normalizeContext(_ value: Any?, error: SolanaRpcClientError) throws -> SolanaRpcContext {
        guard let object = value as? [String: Any] else {
            throw error
        }
        if let apiVersion = object["apiVersion"], !isJSONNull(apiVersion), !(apiVersion is String) {
            throw error
        }

        return SolanaRpcContext(
            apiVersion: object["apiVersion"] as? String,
            slot: try requireUnsignedInt64(object["slot"], error: error)
        )
    }

    private func normalizeAccountInfoExists(_ value: Any) throws -> Bool {
        guard let object = value as? [String: Any] else {
            throw SolanaRpcClientError.invalidAccountInfoResponse
        }
        _ = try Self.normalizeContext(object["context"], error: .invalidAccountInfoResponse)
        guard let accountValue = object["value"] else {
            throw SolanaRpcClientError.invalidAccountInfoResponse
        }
        if Self.isJSONNull(accountValue) {
            return false
        }
        guard accountValue is [String: Any] else {
            throw SolanaRpcClientError.invalidAccountInfoResponse
        }

        return true
    }

    private static func normalizeLatestBlockhash(_ value: Any?, error: SolanaRpcClientError) throws -> SolanaLatestBlockhash {
        guard let object = value as? [String: Any],
              let blockhash = object["blockhash"] as? String,
              matches(blockhash, #"^[1-9A-HJ-NP-Za-km-z]{32,64}$"#) else {
            throw error
        }

        return SolanaLatestBlockhash(
            blockhash: blockhash,
            lastValidBlockHeight: try requireUnsignedInt64(object["lastValidBlockHeight"], error: error)
        )
    }

    private static func requireUnsignedInt64(_ value: Any?, error: SolanaRpcClientError) throws -> Int64 {
        if value is String {
            throw error
        }
        guard let value = int64(value), value >= 0 else {
            throw error
        }

        return value
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? String {
            return Int64(value)
        }
        if let value = value as? Int64 {
            return value
        }
        if let value = value as? Int {
            return Int64(value)
        }
        if let value = value as? UInt64 {
            return Int64(exactly: value)
        }
        if let value = value as? UInt {
            return Int64(exactly: value)
        }
        if let value = value as? Double {
            guard value.isFinite, value.rounded(.towardZero) == value else {
                return nil
            }
            return Int64(exactly: value)
        }
        guard let number = value as? NSNumber, !(value is Bool) else {
            return nil
        }
        let double = number.doubleValue
        guard double.isFinite, double.rounded(.towardZero) == double else {
            return nil
        }

        return number.int64Value
    }

    private static func jsonRpcVersion(_ value: Any?) -> String? {
        if let value = value as? String {
            return value
        }
        if let number = value as? NSNumber, !(value is Bool) {
            return number.stringValue
        }

        return nil
    }

    private static func isJSONNull(_ value: Any?) -> Bool {
        guard let value else {
            return false
        }

        return value is NSNull
    }

    private static func normalizeRPCError(_ value: Any) -> SolanaJsonRpcErrorPayload {
        guard let object = value as? [String: Any] else {
            return SolanaJsonRpcErrorPayload(code: -1, message: "Unknown Solana RPC error", dataJSON: nil)
        }

        return SolanaJsonRpcErrorPayload(
            code: int64(object["code"]).flatMap { Int(exactly: $0) } ?? -1,
            message: object["message"] as? String ?? "Unknown Solana RPC error",
            dataJSON: object["data"].flatMap(jsonString)
        )
    }

    private static func jsonString(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

enum SolanaRpcRoutes {
    private static let maxTransactionBase64Length = 1_000_000
    private static let maxRentDataLength = 10_000_000

    static func normalizeRPCURL(_ rpcURL: String) throws -> String {
        let trimmed = rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme,
              let host = components.host else {
            throw SolanaRpcClientError.invalidRPCURL
        }
        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || isLocal else {
            throw SolanaRpcClientError.invalidRPCURL
        }

        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw SolanaRpcClientError.invalidRPCURL
        }

        return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func normalizeTransactionBase64(_ transactionBase64: String) throws -> String {
        guard !transactionBase64.isEmpty,
              transactionBase64.count <= maxTransactionBase64Length,
              transactionBase64.count % 4 == 0,
              transactionBase64.range(
                  of: #"^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$"#,
                  options: .regularExpression
              ) != nil else {
            throw SolanaRpcClientError.invalidTransaction
        }

        return transactionBase64
    }

    static func normalizeDataLength(_ dataLength: Int) throws -> Int {
        guard (0 ... maxRentDataLength).contains(dataLength) else {
            throw SolanaRpcClientError.invalidDataLength
        }

        return dataLength
    }

    static func normalizePublicKey(_ publicKey: String) throws -> String {
        let trimmed = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^[1-9A-HJ-NP-Za-km-z]{32,44}$"#, options: .regularExpression) != nil else {
            throw SolanaRpcClientError.invalidAccountAddress
        }

        return trimmed
    }
}

enum SolanaRpcCommitment: String, Equatable {
    case processed
    case confirmed
    case finalized
}

struct SolanaBroadcastOptions: Equatable {
    let maxRetries: Int?
    let preflightCommitment: SolanaRpcCommitment
    let skipPreflight: Bool

    init(
        maxRetries: Int? = nil,
        preflightCommitment: SolanaRpcCommitment = .confirmed,
        skipPreflight: Bool = false
    ) {
        self.maxRetries = maxRetries
        self.preflightCommitment = preflightCommitment
        self.skipPreflight = skipPreflight
    }
}

struct SolanaSimulationOptions: Equatable {
    let commitment: SolanaRpcCommitment
    let replaceRecentBlockhash: Bool
    let sigVerify: Bool

    init(
        commitment: SolanaRpcCommitment = .confirmed,
        replaceRecentBlockhash: Bool = true,
        sigVerify: Bool = false
    ) {
        self.commitment = commitment
        self.replaceRecentBlockhash = replaceRecentBlockhash
        self.sigVerify = sigVerify
    }
}

struct SolanaRpcContext: Equatable {
    let apiVersion: String?
    let slot: Int64
}

struct SolanaLatestBlockhash: Equatable {
    let blockhash: String
    let lastValidBlockHeight: Int64
}

struct SolanaLatestBlockhashResponse: Equatable {
    let context: SolanaRpcContext
    let value: SolanaLatestBlockhash
}

struct SolanaFeeForMessageResponse: Equatable {
    let context: SolanaRpcContext
    let value: Int64?
}

struct SolanaSimulationValue: Equatable {
    let errorJSON: String?
    let logs: [String]?
    let replacementBlockhash: SolanaLatestBlockhash?
    let unitsConsumed: Int64?
}

struct SolanaSimulationResponse: Equatable {
    let context: SolanaRpcContext
    let value: SolanaSimulationValue
}

struct SolanaJsonRpcErrorPayload: Equatable {
    let code: Int
    let message: String
    let dataJSON: String?
}

enum SolanaRpcClientError: Error, Equatable {
    case invalidRPCURL
    case invalidAccountAddress
    case invalidTransaction
    case invalidMaxRetries
    case invalidDataLength
    case invalidSimulationOptions
    case httpStatusCode(Int)
    case invalidRPCResponse
    case rpcError(SolanaJsonRpcErrorPayload)
    case invalidBlockhashResponse
    case invalidFeeResponse
    case invalidRentResponse
    case invalidAccountInfoResponse
    case invalidSimulationResponse
    case invalidSignatureResponse
}

private extension Optional where Wrapped == URL {
    func orThrow(_ error: SolanaRpcClientError) throws -> URL {
        guard let value = self else {
            throw error
        }

        return value
    }
}
