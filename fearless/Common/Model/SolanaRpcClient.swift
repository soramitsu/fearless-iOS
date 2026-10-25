import Foundation
import SSFModels

protocol SolanaRpcClientProtocol {
    var expectedGenesisHash: String? { get }
    /// Returns an immutable client bound to the captured network, never a shared mutable setting.
    func bound(toGenesisHash genesisHash: String) throws -> SolanaRpcClientProtocol
    /// Fresh endpoint assertion before sensitive local work; normal RPC operations also recheck.
    func verifyCluster(rpcURL: String?) async throws

    func latestBlockhash(commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> SolanaLatestBlockhashResponse
    func feeForMessage(_ messageBase64: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> SolanaFeeForMessageResponse
    func minimumBalanceForRentExemption(dataLength: Int, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64
    func accountExists(address: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Bool
    func simulateTransaction(_ transactionBase64: String, options: SolanaSimulationOptions, rpcURL: String?) async throws -> SolanaSimulationResponse
    func sendRawTransaction(_ transactionBase64: String, options: SolanaBroadcastOptions, rpcURL: String?) async throws -> String
    /// The account's owner program, lamports and whether it is a program; nil when the
    /// account does not exist.
    func accountInfo(address: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> SolanaAccountInfo?
    func balance(address: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64
    func tokenAccountsByOwner(
        owner: String,
        programId: String,
        commitment: SolanaRpcCommitment,
        rpcURL: String?
    ) async throws -> [SolanaParsedTokenAccount]
    /// One entry per signature, nil when the cluster has never seen it.
    func signatureStatuses(
        _ signatures: [String],
        searchTransactionHistory: Bool,
        rpcURL: String?
    ) async throws -> [SolanaSignatureStatus?]
    func blockHeight(commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64
    func signatureStatusObservation(
        _ signature: String, rpcURL: String?
    ) async throws -> SolanaSignatureStatusObservation
    func blockhashValidity(
        _ blockhash: String, minContextSlot: Int64?, rpcURL: String?
    ) async throws -> SolanaBlockhashValidity
    func finalizedBlockhash(slot: Int64, rpcURL: String?) async throws -> String?
    /// Recent compute-unit prices (micro-lamports) paid by transactions that wrote the given
    /// accounts.
    func recentPrioritizationFees(accounts: [String], rpcURL: String?) async throws -> [Int64]
    /// Whether a signed transaction landed, expired or may still land. A default
    /// implementation asks one node; the failover client asks each node in turn.
    func resolveSignature(
        _ signature: String,
        transaction: ParsedSolanaTransaction,
        blockhashContextSlot: Int64?,
        rpcURL: String?
    ) async throws -> SolanaSignatureResolution
}

final class SolanaRpcClient: SolanaRpcClientProtocol {
    private let transport: UniversalWalletHTTPTransport
    private let defaultRPCURL: String
    private let pacer: SolanaRpcRequestPacer
    let expectedGenesisHash: String?
    /// One client serves every screen's requests at once (the failover client and the app's
    /// mainnet balance reader are shared), so ids are handed out under a lock.
    private var nextId: Int64 = 1
    private let idLock = NSLock()

    init(
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        defaultRPCURL: String = UniversalWalletRegistry.solanaMainnetRPCURL.absoluteString,
        expectedGenesisHash: String = UniversalWalletRegistry.solanaMainnet.genesisHash,
        pacer: SolanaRpcRequestPacer = .shared
    ) throws {
        _ = try SolanaRpcRoutes.normalizeRPCURL(defaultRPCURL)
        self.transport = transport
        self.defaultRPCURL = defaultRPCURL
        self.pacer = pacer
        self.expectedGenesisHash = try SolanaRpcRoutes.normalizePublicKey(expectedGenesisHash)
    }

    func bound(toGenesisHash genesisHash: String) throws -> SolanaRpcClientProtocol {
        if expectedGenesisHash == genesisHash { return self }
        return try SolanaRpcClient(
            transport: transport,
            defaultRPCURL: defaultRPCURL,
            expectedGenesisHash: genesisHash,
            pacer: pacer
        )
    }

    func verifyCluster(rpcURL: String?) async throws {
        let actual: String = try await uncheckedRequest(method: "getGenesisHash", params: [], rpcURL: rpcURL) { value in
            guard let hash = value as? String, (try? SolanaRpcRoutes.normalizePublicKey(hash)) == hash else {
                throw SolanaRpcClientError.invalidGenesisHash
            }
            return hash
        }
        guard actual == expectedGenesisHash else { throw SolanaRpcClientError.clusterMismatch }
        try Task.checkCancellation()
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
                SolanaRpcRoutes.normalizeTransactionBase64(messageBase64),
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
                SolanaRpcRoutes.normalizeDataLength(dataLength),
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
                SolanaRpcRoutes.normalizePublicKey(address),
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
                SolanaRpcRoutes.normalizeTransactionBase64(transactionBase64),
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
                SolanaRpcRoutes.normalizeTransactionBase64(transactionBase64),
                rpcOptions
            ],
            rpcURL: rpcURL,
            normalize: normalizeSignature
        )
    }

    func accountInfo(
        address: String,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> SolanaAccountInfo? {
        try await request(
            method: "getAccountInfo",
            params: [
                SolanaRpcRoutes.normalizePublicKey(address),
                [
                    "commitment": commitment.rawValue,
                    "encoding": "base64",
                    // Only the owner, lamports and program flag are needed, never the data.
                    "dataSlice": ["offset": 0, "length": 0]
                ]
            ],
            rpcURL: rpcURL,
            normalize: normalizeAccountInfo
        )
    }

    func balance(
        address: String,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> Int64 {
        try await request(
            method: "getBalance",
            params: [
                SolanaRpcRoutes.normalizePublicKey(address),
                ["commitment": commitment.rawValue]
            ],
            rpcURL: rpcURL
        ) { value in
            guard let object = value as? [String: Any] else {
                throw SolanaRpcClientError.invalidBalanceResponse
            }
            _ = try Self.normalizeContext(object["context"], error: .invalidBalanceResponse)
            return try Self.requireUnsignedInt64(object["value"], error: .invalidBalanceResponse)
        }
    }

    func tokenAccountsByOwner(
        owner: String,
        programId: String,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> [SolanaParsedTokenAccount] {
        let normalizedOwner = try SolanaRpcRoutes.normalizePublicKey(owner)
        return try await request(
            method: "getTokenAccountsByOwner",
            params: [
                normalizedOwner,
                ["programId": SolanaRpcRoutes.normalizePublicKey(programId)],
                [
                    "commitment": commitment.rawValue,
                    "encoding": "jsonParsed"
                ]
            ],
            rpcURL: rpcURL
        ) { value in
            try Self.normalizeTokenAccounts(value, programId: programId)
        }
    }

    func signatureStatuses(
        _ signatures: [String], searchTransactionHistory: Bool = true, rpcURL: String? = nil
    ) async throws -> [SolanaSignatureStatus?] {
        try await signatureObservations(
            signatures, searchTransactionHistory: searchTransactionHistory, rpcURL: rpcURL
        ).statuses
    }

    func signatureStatusObservation(
        _ signature: String, rpcURL: String?
    ) async throws -> SolanaSignatureStatusObservation {
        let answer = try await signatureObservations([signature], searchTransactionHistory: true, rpcURL: rpcURL)
        return SolanaSignatureStatusObservation(context: answer.context, status: answer.statuses.first ?? nil)
    }

    func blockhashValidity(
        _ blockhash: String, minContextSlot: Int64?, rpcURL: String?
    ) async throws -> SolanaBlockhashValidity {
        let normalized = try SolanaRpcRoutes.normalizePublicKey(blockhash)
        var config: [String: Any] = ["commitment": SolanaRpcCommitment.finalized.rawValue]
        if let minContextSlot {
            guard minContextSlot >= 0 else { throw SolanaRpcClientError.invalidBlockhashResponse }
            config["minContextSlot"] = minContextSlot
        }
        return try await request(method: "isBlockhashValid", params: [normalized, config], rpcURL: rpcURL) { value in
            guard let object = value as? [String: Any],
                  let number = object["value"] as? NSNumber,
                  CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw SolanaRpcClientError.invalidBlockhashResponse
            }
            return try SolanaBlockhashValidity(
                context: Self.normalizeContext(object["context"], error: .invalidBlockhashResponse),
                isValid: number.boolValue
            )
        }
    }

    func finalizedBlockhash(slot: Int64, rpcURL: String?) async throws -> String? {
        guard slot >= 0 else { throw SolanaRpcClientError.invalidBlockhashResponse }
        return try await request(
            method: "getBlock",
            params: [slot, ["commitment": "finalized", "transactionDetails": "none", "rewards": false]],
            rpcURL: rpcURL
        ) { value in
            if value is NSNull { return nil }
            guard let object = value as? [String: Any], let hash = object["blockhash"] as? String else {
                throw SolanaRpcClientError.invalidBlockhashResponse
            }
            return try SolanaRpcRoutes.normalizePublicKey(hash)
        }
    }

    private func signatureObservations(
        _ signatures: [String],
        searchTransactionHistory: Bool = true,
        rpcURL: String? = nil
    ) async throws -> (context: SolanaRpcContext, statuses: [SolanaSignatureStatus?]) {
        guard (1 ... SolanaRpcRoutes.maxSignatureStatuses).contains(signatures.count) else {
            throw SolanaRpcClientError.invalidSignature
        }
        let normalized = try signatures.map(SolanaRpcRoutes.normalizeSignature)

        return try await request(
            method: "getSignatureStatuses",
            params: [
                normalized,
                ["searchTransactionHistory": searchTransactionHistory]
            ],
            rpcURL: rpcURL
        ) { value in
            guard let object = value as? [String: Any] else {
                throw SolanaRpcClientError.invalidSignatureStatusResponse
            }
            return try (
                Self.normalizeContext(object["context"], error: .invalidSignatureStatusResponse),
                Self.normalizeSignatureStatuses(value, count: normalized.count)
            )
        }
    }

    func blockHeight(
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil
    ) async throws -> Int64 {
        try await request(
            method: "getBlockHeight",
            params: [["commitment": commitment.rawValue]],
            rpcURL: rpcURL
        ) { value in
            try Self.requireUnsignedInt64(value, error: .invalidBlockHeightResponse)
        }
    }

    func recentPrioritizationFees(
        accounts: [String],
        rpcURL: String? = nil
    ) async throws -> [Int64] {
        guard accounts.count <= SolanaRpcRoutes.maxPrioritizationFeeAccounts else {
            throw SolanaRpcClientError.invalidAccountAddress
        }
        let normalized = try accounts.map(SolanaRpcRoutes.normalizePublicKey)

        return try await request(
            method: "getRecentPrioritizationFees",
            params: [normalized],
            rpcURL: rpcURL
        ) { value in
            guard let entries = value as? [Any] else {
                throw SolanaRpcClientError.invalidPrioritizationFeeResponse
            }
            return try entries.map { entry in
                guard let object = entry as? [String: Any] else {
                    throw SolanaRpcClientError.invalidPrioritizationFeeResponse
                }
                return try Self.requireUnsignedInt64(
                    object["prioritizationFee"],
                    error: .invalidPrioritizationFeeResponse
                )
            }
        }
    }

    private func request<T>(
        method: String,
        params: [Any],
        rpcURL: String?,
        normalize: (Any) throws -> T
    ) async throws -> T {
        // No cached attestation: a provider can change its backing cluster between requests.
        try await verifyCluster(rpcURL: rpcURL)
        return try await uncheckedRequest(method: method, params: params, rpcURL: rpcURL, normalize: normalize)
    }

    private func uncheckedRequest<T>(
        method: String,
        params: [Any],
        rpcURL: String?,
        normalize: (Any) throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        let id = makeRequestId()
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

        // Requests to a node that allows only a few a second wait their turn, whichever client
        // or screen sends them; the cluster check counts as a request.
        let endpoint = url.absoluteString
        let spacing = SolanaRpcEndpoints.requestSpacing(for: endpoint)
        try await pacer.waitForTurn(endpoint, spacing: spacing)

        let data: Data
        do {
            if method == "sendTransaction" { try SolanaSendAuthorization.requireCurrent() }
            data = try await transport.perform(request)
        } catch let UniversalWalletHTTPTransportError.httpStatusCode(status, _) {
            throw SolanaRpcClientError.httpStatusCode(status)
        } catch let UniversalWalletHTTPTransportError.rateLimited(status, _) {
            // "Too many requests" (whatever the body, often an HTML page) is the node asking for
            // a pause, not an answer: the next request to it waits a little longer.
            if spacing > 0 {
                pacer.holdBack(endpoint, for: SolanaRpcRequestPacer.rateLimitPause)
            }
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

    private func makeRequestId() -> Int64 {
        idLock.lock()
        defer { idLock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }

    private func normalizeLatestBlockhashResponse(_ value: Any) throws -> SolanaLatestBlockhashResponse {
        guard let object = value as? [String: Any] else {
            throw SolanaRpcClientError.invalidBlockhashResponse
        }
        return try SolanaLatestBlockhashResponse(
            context: Self.normalizeContext(object["context"], error: .invalidBlockhashResponse),
            value: Self.normalizeLatestBlockhash(object["value"], error: .invalidBlockhashResponse)
        )
    }

    private func normalizeFeeForMessageResponse(_ value: Any) throws -> SolanaFeeForMessageResponse {
        guard let object = value as? [String: Any] else {
            throw SolanaRpcClientError.invalidFeeResponse
        }
        let fee = Self.isJSONNull(object["value"])
            ? nil
            : try Self.requireUnsignedInt64(object["value"], error: .invalidFeeResponse)

        return try SolanaFeeForMessageResponse(
            context: Self.normalizeContext(object["context"], error: .invalidFeeResponse),
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

        return try SolanaSimulationResponse(
            context: Self.normalizeContext(object["context"], error: .invalidSimulationResponse),
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
        guard let object = value as? [String: Any],
              let slot = object["slot"] as? NSNumber,
              CFGetTypeID(slot) != CFBooleanGetTypeID() else {
            throw error
        }
        if let apiVersion = object["apiVersion"], !isJSONNull(apiVersion), !(apiVersion is String) {
            throw error
        }

        return try SolanaRpcContext(
            apiVersion: object["apiVersion"] as? String,
            slot: requireUnsignedInt64(object["slot"], error: error)
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

    private func normalizeAccountInfo(_ value: Any) throws -> SolanaAccountInfo? {
        guard let object = value as? [String: Any] else {
            throw SolanaRpcClientError.invalidAccountInfoResponse
        }
        _ = try Self.normalizeContext(object["context"], error: .invalidAccountInfoResponse)
        guard let accountValue = object["value"] else {
            throw SolanaRpcClientError.invalidAccountInfoResponse
        }
        if Self.isJSONNull(accountValue) {
            return nil
        }
        guard let account = accountValue as? [String: Any],
              let owner = account["owner"] as? String,
              let executable = account["executable"] as? Bool,
              Self.matches(owner, #"^[1-9A-HJ-NP-Za-km-z]{32,44}$"#) else {
            throw SolanaRpcClientError.invalidAccountInfoResponse
        }

        return try SolanaAccountInfo(
            owner: owner,
            lamports: Self.requireUnsignedInt64(account["lamports"], error: .invalidAccountInfoResponse),
            executable: executable
        )
    }

    private static func normalizeTokenAccounts(_ value: Any, programId: String) throws -> [SolanaParsedTokenAccount] {
        guard let object = value as? [String: Any],
              let entries = object["value"] as? [Any] else {
            throw SolanaRpcClientError.invalidTokenAccountsResponse
        }
        _ = try normalizeContext(object["context"], error: .invalidTokenAccountsResponse)

        // An entry the node cannot parse (an unknown extension layout) is skipped rather than
        // failing the whole wallet: the other token balances are still true.
        return entries.compactMap { entry in
            guard let entry = entry as? [String: Any],
                  let pubkey = entry["pubkey"] as? String,
                  matches(pubkey, #"^[1-9A-HJ-NP-Za-km-z]{32,44}$"#),
                  let account = entry["account"] as? [String: Any],
                  account["owner"] as? String == programId,
                  let data = account["data"] as? [String: Any],
                  let parsed = data["parsed"] as? [String: Any],
                  parsed["type"] as? String == "account",
                  let info = parsed["info"] as? [String: Any],
                  let mint = info["mint"] as? String,
                  matches(mint, #"^[1-9A-HJ-NP-Za-km-z]{32,44}$"#),
                  let owner = info["owner"] as? String,
                  let tokenAmount = info["tokenAmount"] as? [String: Any],
                  let amount = tokenAmount["amount"] as? String,
                  matches(amount, #"^(0|[1-9][0-9]*)$"#),
                  let decimals = int64(tokenAmount["decimals"]),
                  (0 ... 255).contains(decimals) else {
                return nil
            }

            return SolanaParsedTokenAccount(
                address: pubkey,
                mint: mint,
                owner: owner,
                amount: amount,
                decimals: Int(decimals),
                uiAmountString: tokenAmount["uiAmountString"] as? String,
                programId: programId,
                program: data["program"] as? String,
                state: info["state"] as? String,
                isNative: info["isNative"] as? Bool ?? false
            )
        }
    }

    private static func normalizeSignatureStatuses(_ value: Any, count: Int) throws -> [SolanaSignatureStatus?] {
        guard let object = value as? [String: Any],
              let entries = object["value"] as? [Any],
              entries.count == count else {
            throw SolanaRpcClientError.invalidSignatureStatusResponse
        }
        _ = try normalizeContext(object["context"], error: .invalidSignatureStatusResponse)

        return try entries.map { entry in
            if isJSONNull(entry) {
                return nil
            }
            guard let status = entry as? [String: Any] else {
                throw SolanaRpcClientError.invalidSignatureStatusResponse
            }
            let confirmationStatus = (status["confirmationStatus"] as? String)
                .flatMap(SolanaRpcCommitment.init(rawValue:))
            let errorJSON: String?
            if let errorValue = status["err"], !isJSONNull(errorValue) {
                errorJSON = jsonString(errorValue) ?? String(describing: errorValue)
            } else {
                errorJSON = nil
            }

            return try SolanaSignatureStatus(
                slot: requireUnsignedInt64(status["slot"], error: .invalidSignatureStatusResponse),
                confirmationStatus: confirmationStatus,
                errorJSON: errorJSON
            )
        }
    }

    private static func normalizeLatestBlockhash(_ value: Any?, error: SolanaRpcClientError) throws -> SolanaLatestBlockhash {
        guard let object = value as? [String: Any],
              let blockhash = object["blockhash"] as? String,
              matches(blockhash, #"^[1-9A-HJ-NP-Za-km-z]{32,64}$"#) else {
            throw error
        }

        return try SolanaLatestBlockhash(
            blockhash: blockhash,
            lastValidBlockHeight: requireUnsignedInt64(object["lastValidBlockHeight"], error: error)
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
    static let maxSignatureStatuses = 256
    static let maxPrioritizationFeeAccounts = 128
    private static let maxTransactionBase64Length = 1_000_000
    private static let maxRentDataLength = 10_000_000

    static func normalizeSignature(_ signature: String) throws -> String {
        let trimmed = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^[1-9A-HJ-NP-Za-km-z]{64,128}$"#, options: .regularExpression) != nil else {
            throw SolanaRpcClientError.invalidSignature
        }

        return trimmed
    }

    static func normalizeRPCURL(_ rpcURL: String) throws -> String {
        let trimmed = rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw SolanaRpcClientError.invalidRPCURL
        }
        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || isLocal else {
            throw SolanaRpcClientError.invalidRPCURL
        }

        // Scheme and host are case-insensitive; the path, which may carry a key, is kept.
        components.scheme = scheme
        if components.host != host {
            components.host = host
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

    /// The same options without the node's simulation, for bytes an earlier node may already
    /// have relayed: a simulation would only see that copy ("already processed") and refuse.
    var skippingPreflight: SolanaBroadcastOptions {
        SolanaBroadcastOptions(maxRetries: maxRetries, preflightCommitment: preflightCommitment, skipPreflight: true)
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

struct SolanaAccountInfo: Equatable {
    let owner: String
    let lamports: Int64
    let executable: Bool
}

/// A token account as `getTokenAccountsByOwner` with `jsonParsed` encoding reports it.
struct SolanaParsedTokenAccount: Equatable {
    let address: String
    let mint: String
    let owner: String
    let amount: String
    let decimals: Int
    let uiAmountString: String?
    let programId: String
    let program: String?
    let state: String?
    let isNative: Bool
}

struct SolanaSignatureStatus: Equatable {
    let slot: Int64
    /// nil while the transaction has only been processed by the answering node.
    let confirmationStatus: SolanaRpcCommitment?
    /// The on-chain error when the transaction was included but failed.
    let errorJSON: String?

    var isConfirmed: Bool {
        confirmationStatus == .confirmed || confirmationStatus == .finalized
    }
}

enum SolanaRpcClientError: Error, Equatable {
    case unboundCluster
    case invalidGenesisHash
    case clusterMismatch
    case invalidRPCURL
    case invalidAccountAddress
    case invalidTransaction
    case invalidSignature
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
    case invalidBalanceResponse
    case invalidTokenAccountsResponse
    case invalidSignatureStatusResponse
    case invalidBlockHeightResponse
    case invalidPrioritizationFeeResponse
}

private extension Optional where Wrapped == URL {
    func orThrow(_ error: SolanaRpcClientError) throws -> URL {
        guard let value = self else {
            throw error
        }

        return value
    }
}

/// What the cluster can prove about a signed transaction whose broadcast outcome is unknown.
enum SolanaSignatureResolution: Equatable {
    /// A confirmed or finalized block holds it; `errorJSON` tells whether it failed on chain.
    case landed(SolanaSignatureStatus)
    /// The blockhash it was signed with has expired and none of the nodes that answered has a
    /// trace of it, so it can no longer be processed. `provingHosts` are the distinct hosts
    /// that each proved this (`SolanaRpcEndpoints.expiryWitnessHost`). One host is not enough
    /// to say nothing left the wallet: a node whose backend lacks that slot's history answers
    /// nothing for a transaction that landed.
    case expired(provingHosts: Set<String>)
    /// No confirmed trace yet, but it could still land.
    case pending
}

extension SolanaRpcClientProtocol {
    var expectedGenesisHash: String? { nil }

    func bound(toGenesisHash _: String) throws -> SolanaRpcClientProtocol {
        throw SolanaRpcClientError.unboundCluster
    }

    func verifyCluster(rpcURL _: String?) async throws {
        throw SolanaRpcClientError.unboundCluster
    }
}

/// How one node answered a broadcast. Only `ambiguous` can mean the transaction is with the
/// cluster without the wallet knowing.
enum SolanaBroadcastAttemptOutcome: Equatable {
    /// The request never reached a node that could forward it (no connection, DNS, TLS), the
    /// node turned the app away before reading it (HTTP 401/403/429), or it could not take a
    /// transaction at all (`cannotTakeTransactionCodes`). The next node is asked.
    case notSent
    /// The node judged the transaction before relaying it (`judgedTransactionCodes`): a
    /// failed simulation, a bad signature, bytes it could not decode. Every node would judge
    /// the same bytes the same way.
    case refused(SolanaJsonRpcErrorPayload?)
    /// A timeout, a dropped connection, a 5xx, an unreadable reply or any other JSON-RPC error:
    /// the node may have forwarded it.
    case ambiguous

    init(error: Error) {
        switch error {
        case let SolanaRpcClientError.httpStatusCode(status):
            self = [401, 403, 404, 405, 413, 429].contains(status) ? .notSent : .ambiguous
        case let SolanaRpcClientError.rpcError(payload):
            if Self.judgedTransactionCodes.contains(payload.code) {
                self = .refused(payload)
            } else if Self.cannotTakeTransactionCodes.contains(payload.code) {
                self = .notSent
            } else {
                // -32603 internal error, the -32000...-32099 server range, gateway quota and
                // auth codes, anything unexpected: the post may already have been relayed.
                self = .ambiguous
            }
        case SolanaRpcClientError.unboundCluster,
             SolanaRpcClientError.invalidGenesisHash,
             SolanaRpcClientError.clusterMismatch,
             SolanaRpcClientError.invalidRPCURL,
             SolanaRpcClientError.invalidTransaction,
             SolanaRpcClientError.invalidMaxRetries:
            self = .notSent
        case let error as URLError:
            self = Self.neverConnected.contains(error.code) ? .notSent : .ambiguous
        default:
            self = .ambiguous
        }
    }

    /// The node judged the transaction and did not forward it: preflight simulation failed
    /// (-32002), the signature check failed (-32003), the request or its bytes were invalid
    /// (-32600, -32602) or could not be decoded (-32700).
    static let judgedTransactionCodes: Set<Int> = [-32002, -32003, -32600, -32602, -32700]

    /// The node could not take a transaction and forwarded nothing: no such method (-32601),
    /// or it is behind or missing the state it needs (-32004, -32005, -32014, -32016).
    static let cannotTakeTransactionCodes: Set<Int> = [-32601, -32004, -32005, -32014, -32016]

    private static let neverConnected: Set<URLError.Code> = [
        .notConnectedToInternet,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .secureConnectionFailed,
        .serverCertificateUntrusted,
        .serverCertificateHasBadDate,
        .serverCertificateNotYetValid,
        .serverCertificateHasUnknownRoot,
        .clientCertificateRejected,
        .clientCertificateRequired,
        .appTransportSecurityRequiresSecureConnection,
        .dataNotAllowed,
        .internationalRoamingOff,
        .callIsActive,
        .unsupportedURL,
        .badURL
    ]
}

/// Every node refused or was unreachable; `attempts` says how each one answered.
struct SolanaBroadcastFailure: Error, Equatable {
    let attempts: [SolanaBroadcastAttemptOutcome]

    /// Some node may have forwarded the transaction, so the wallet must look it up before
    /// it may say "not sent".
    var mayHaveReachedCluster: Bool {
        attempts.isEmpty || attempts.contains(.ambiguous)
    }

    /// At least one node read the transaction and refused it.
    var someNodeRefused: Bool {
        attempts.contains {
            if case .refused = $0 {
                return true
            }
            return false
        }
    }
}

/// Sends each Solana JSON-RPC request to the first healthy node of the wallet's list and,
/// when that node is unreachable, failing, rate limiting or turning the app away (HTTP
/// 401/403), to the next one. Public nodes answer the same JSON-RPC, so a refusal from one
/// (for example publicnode's "Request blocked" for token accounts) is retried on the others.
/// A caller that names a node outside the list talks to that node only.
final class SolanaFailoverRpcClient: SolanaRpcClientProtocol {
    /// Solana mainnet: the build's provider, if any, then the public nodes.
    static let mainnet: SolanaFailoverRpcClient? = try? SolanaFailoverRpcClient(
        endpoints: SolanaRpcEndpoints.endpoints(
            for: UniversalWalletRegistry.solanaMainnetChainModel,
            network: UniversalWalletRegistry.solanaMainnet
        )
    )

    let endpoints: [String]
    var expectedGenesisHash: String? { client.expectedGenesisHash }
    private let transport: UniversalWalletHTTPTransport
    private let pacer: SolanaRpcRequestPacer

    private let client: SolanaRpcClientProtocol
    private let health: UniversalWalletEndpointHealth

    init(
        endpoints: [String],
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        health: UniversalWalletEndpointHealth = .solanaRpc,
        expectedGenesisHash: String = UniversalWalletRegistry.solanaMainnet.genesisHash,
        pacer: SolanaRpcRequestPacer = .shared
    ) throws {
        let normalized = try endpoints.map(SolanaRpcRoutes.normalizeRPCURL)
        guard let first = normalized.first else {
            throw SolanaRpcClientError.invalidRPCURL
        }
        self.endpoints = normalized.reduce(into: [String]()) { result, endpoint in
            if !result.contains(endpoint) {
                result.append(endpoint)
            }
        }
        client = try SolanaRpcClient(
            transport: transport,
            defaultRPCURL: first,
            expectedGenesisHash: expectedGenesisHash,
            pacer: pacer
        )
        self.health = health
        self.transport = transport
        self.pacer = pacer
    }

    func bound(toGenesisHash genesisHash: String) throws -> SolanaRpcClientProtocol {
        if expectedGenesisHash == genesisHash { return self }
        return try SolanaFailoverRpcClient(
            endpoints: endpoints,
            transport: transport,
            health: health,
            expectedGenesisHash: genesisHash,
            pacer: pacer
        )
    }

    func verifyCluster(rpcURL: String?) async throws {
        try await read(rpcURL) { try await self.client.verifyCluster(rpcURL: $0) }
    }

    func latestBlockhash(commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> SolanaLatestBlockhashResponse {
        try await read(rpcURL) { try await self.client.latestBlockhash(commitment: commitment, rpcURL: $0) }
    }

    func feeForMessage(
        _ messageBase64: String,
        commitment: SolanaRpcCommitment,
        rpcURL: String?
    ) async throws -> SolanaFeeForMessageResponse {
        try await read(rpcURL) { try await self.client.feeForMessage(messageBase64, commitment: commitment, rpcURL: $0) }
    }

    func minimumBalanceForRentExemption(
        dataLength: Int,
        commitment: SolanaRpcCommitment,
        rpcURL: String?
    ) async throws -> Int64 {
        try await read(rpcURL) {
            try await self.client.minimumBalanceForRentExemption(dataLength: dataLength, commitment: commitment, rpcURL: $0)
        }
    }

    func accountExists(address: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Bool {
        try await read(rpcURL) { try await self.client.accountExists(address: address, commitment: commitment, rpcURL: $0) }
    }

    func simulateTransaction(
        _ transactionBase64: String,
        options: SolanaSimulationOptions,
        rpcURL: String?
    ) async throws -> SolanaSimulationResponse {
        try await read(rpcURL) { try await self.client.simulateTransaction(transactionBase64, options: options, rpcURL: $0) }
    }

    /// Offers the same signed transaction to each node until one accepts it. The bytes, and so
    /// the signature, are identical every time: a second node can only accept or refuse the
    /// same payment, never make a second one.
    ///
    /// A node that judged the transaction (a refusal) ends the broadcast while no node may
    /// have relayed it: every node would judge the same bytes the same way. After a node that
    /// may have relayed it, the rest get the same bytes without a simulation, which would only
    /// see that copy.
    func sendRawTransaction(
        _ transactionBase64: String,
        options: SolanaBroadcastOptions,
        rpcURL: String?
    ) async throws -> String {
        var attempts: [SolanaBroadcastAttemptOutcome] = []
        var attemptOptions = options

        for endpoint in healthOrdered(candidates(rpcURL)) {
            do {
                let signature = try await client.sendRawTransaction(transactionBase64, options: attemptOptions, rpcURL: endpoint)
                health.markSuccess(endpoint)
                return signature
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let outcome = SolanaBroadcastAttemptOutcome(error: error)
                // A node that turned the app away or could not take it is backed off; one that
                // read the transaction and refused it (a failed simulation) did its job.
                if outcome == .notSent, Self.isServiceProblem(error) {
                    health.markFailure(endpoint)
                }
                attempts.append(outcome)
                switch outcome {
                case .refused where !attempts.contains(.ambiguous):
                    throw SolanaBroadcastFailure(attempts: attempts)
                case .ambiguous:
                    attemptOptions = options.skippingPreflight
                case .notSent, .refused:
                    break
                }
            }
        }

        throw SolanaBroadcastFailure(attempts: attempts)
    }

    func accountInfo(address: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> SolanaAccountInfo? {
        try await read(rpcURL) { try await self.client.accountInfo(address: address, commitment: commitment, rpcURL: $0) }
    }

    func balance(address: String, commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64 {
        try await read(rpcURL) { try await self.client.balance(address: address, commitment: commitment, rpcURL: $0) }
    }

    func tokenAccountsByOwner(
        owner: String,
        programId: String,
        commitment: SolanaRpcCommitment,
        rpcURL: String?
    ) async throws -> [SolanaParsedTokenAccount] {
        try await read(rpcURL) {
            try await self.client.tokenAccountsByOwner(owner: owner, programId: programId, commitment: commitment, rpcURL: $0)
        }
    }

    /// Asks every node that answers: a signature counts as seen as soon as one node has it,
    /// and as unseen only when at least one node answered and none had it.
    func signatureStatuses(
        _ signatures: [String],
        searchTransactionHistory: Bool,
        rpcURL: String?
    ) async throws -> [SolanaSignatureStatus?] {
        var merged: [SolanaSignatureStatus?]?
        var lastError: Error?

        for endpoint in candidates(rpcURL) {
            do {
                let statuses = try await client.signatureStatuses(
                    signatures,
                    searchTransactionHistory: searchTransactionHistory,
                    rpcURL: endpoint
                )
                merged = zip(merged ?? statuses, statuses).map { current, next in
                    Self.moreConfirmed(current, next)
                }
                if merged?.allSatisfy({ $0?.confirmationStatus == .finalized }) == true {
                    break
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        guard let merged else {
            throw lastError ?? SolanaRpcClientError.invalidSignatureStatusResponse
        }
        return merged
    }

    func blockHeight(commitment: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64 {
        try await read(rpcURL) { try await self.client.blockHeight(commitment: commitment, rpcURL: $0) }
    }

    func recentPrioritizationFees(accounts: [String], rpcURL: String?) async throws -> [Int64] {
        try await read(rpcURL) { try await self.client.recentPrioritizationFees(accounts: accounts, rpcURL: $0) }
    }

    /// Keep each proof on one endpoint. A live or unproven answer vetoes expiry;
    /// a positive transaction status wins. Missing responses never supply proof. Expiry
    /// reports every distinct host that proved it, so two endpoints on one host count once.
    func resolveSignature(
        _ signature: String,
        transaction: ParsedSolanaTransaction,
        blockhashContextSlot: Int64?,
        rpcURL: String?
    ) async throws -> SolanaSignatureResolution {
        var provingHosts: Set<String> = []
        var stillPossible = false
        var lastError: Error?

        for endpoint in candidates(rpcURL) {
            do {
                let answer = try await client.resolveSignature(
                    signature,
                    transaction: transaction,
                    blockhashContextSlot: blockhashContextSlot,
                    rpcURL: endpoint
                )
                switch answer {
                case .landed:
                    return answer
                case let .expired(hosts):
                    provingHosts.formUnion(hosts)
                case .pending:
                    stillPossible = true
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        if stillPossible {
            return .pending
        }
        guard !provingHosts.isEmpty else {
            throw lastError ?? SolanaRpcClientError.invalidSignatureStatusResponse
        }
        return .expired(provingHosts: provingHosts)
    }

    private func candidates(_ rpcURL: String?) -> [String] {
        guard let rpcURL, let normalized = try? SolanaRpcRoutes.normalizeRPCURL(rpcURL) else {
            return endpoints
        }
        guard let index = endpoints.firstIndex(of: normalized) else {
            return [normalized]
        }

        return Array(endpoints[index...] + endpoints[..<index])
    }

    /// Nodes that are not backing off come first. The others are still asked, last, rather
    /// than leave the user with nothing: the backoff is a courtesy, not a contract.
    private func healthOrdered(_ candidates: [String]) -> [String] {
        let available = health.available(candidates)
        return available + candidates.filter { !available.contains($0) }
    }

    private func read<T>(_ rpcURL: String?, _ request: (String) async throws -> T) async throws -> T {
        var lastError: Error?
        var askedToPause: [String] = []
        for endpoint in healthOrdered(candidates(rpcURL)) {
            do {
                let value = try await request(endpoint)
                health.markSuccess(endpoint)
                return value
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if Self.isRequestProblem(error) {
                    // The request is wrong before any node saw it; no other node would help.
                    throw error
                }
                if Self.isServiceProblem(error) {
                    health.markFailure(endpoint)
                }
                if Self.isTooManyRequests(error), SolanaRpcEndpoints.requestSpacing(for: endpoint) > 0 {
                    askedToPause.append(endpoint)
                }
                lastError = error
            }
        }

        // A node that allows only a few requests a second and answered "too many requests"
        // is asked once more, after the pause the pacer now keeps before its next request.
        for endpoint in askedToPause {
            do {
                let value = try await request(endpoint)
                health.markSuccess(endpoint)
                return value
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError ?? SolanaRpcClientError.invalidRPCResponse
    }

    private static func isTooManyRequests(_ error: Error) -> Bool {
        if case SolanaRpcClientError.httpStatusCode(429) = error {
            return true
        }
        return false
    }

    /// Errors raised by the wallet's own validation before anything was sent.
    private static func isRequestProblem(_ error: Error) -> Bool {
        switch error {
        case SolanaRpcClientError.invalidAccountAddress,
             SolanaRpcClientError.invalidTransaction,
             SolanaRpcClientError.invalidSignature,
             SolanaRpcClientError.invalidMaxRetries,
             SolanaRpcClientError.invalidDataLength,
             SolanaRpcClientError.invalidSimulationOptions,
             SolanaRpcClientError.invalidRPCURL:
            return true
        default:
            return false
        }
    }

    /// The node is rate limiting, failing or refusing the app: leave it alone for a while.
    /// Being offline is not the node's fault and does not hold it back.
    private static func isServiceProblem(_ error: Error) -> Bool {
        switch error {
        case SolanaRpcClientError.httpStatusCode:
            return true
        case let SolanaRpcClientError.rpcError(payload):
            // -32005 node behind, -32603 internal error, and the -32000...-32099 server
            // range providers use for rate limits; -32602/-32601 are a node refusing a method.
            return payload.code <= -32000 || payload.code == -32601
        default:
            return false
        }
    }

    private static func moreConfirmed(
        _ current: SolanaSignatureStatus?,
        _ next: SolanaSignatureStatus?
    ) -> SolanaSignatureStatus? {
        guard let current else {
            return next
        }
        guard let next else {
            return current
        }

        return rank(next.confirmationStatus) > rank(current.confirmationStatus) ? next : current
    }

    private static func rank(_ commitment: SolanaRpcCommitment?) -> Int {
        switch commitment {
        case .finalized:
            return 3
        case .confirmed:
            return 2
        case .processed:
            return 1
        case nil:
            return 0
        }
    }
}

/// Keeps the wallet's requests to a rate-limited node apart. Every Solana client in the app
/// shares one pacer, so two screens reading at once still ask such a node one request at a
/// time, each `spacing` after the last.
final class SolanaRpcRequestPacer {
    static let shared = SolanaRpcRequestPacer()
    /// How long a rate-limited node is left alone after it answers "too many requests".
    static let rateLimitPause: TimeInterval = 1

    private let lock = NSLock()
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void
    private var nextTurn: [String: Date] = [:]

    init(
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.now = now
        self.sleep = sleep
    }

    /// Waits until `endpoint` may be asked and books the turn after this one. A node without
    /// a spacing is never held up.
    func waitForTurn(_ endpoint: String, spacing: TimeInterval) async throws {
        guard spacing > 0 else {
            return
        }
        lock.lock()
        let date = now()
        let turn = max(date, nextTurn[endpoint] ?? .distantPast)
        nextTurn[endpoint] = turn.addingTimeInterval(spacing)
        lock.unlock()

        let delay = turn.timeIntervalSince(date)
        if delay > 0 {
            try await sleep(delay)
        }
    }

    /// The node asked for a pause: its next request waits at least `pause` from now.
    func holdBack(_ endpoint: String, for pause: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        let resume = now().addingTimeInterval(pause)
        nextTurn[endpoint] = max(nextTurn[endpoint] ?? .distantPast, resume)
    }
}

/// The JSON-RPC nodes a Solana network is read from and broadcast to, in order.
enum SolanaRpcEndpoints {
    /// The build's own RPC provider (`FL_SOLANA_RPC_URL` in CI), asked before the public
    /// nodes on mainnet. It must be an `https` URL that carries any key in its path, because
    /// the client drops query strings. It is optional: empty, missing or malformed means no
    /// provider, and the public nodes alone serve the wallet.
    static var configuredProviderURL: String? {
        providerURL(SolanaRpcCIKeys.providerURL)
    }

    /// A provider value the wallet may use, or nil. Only `https` with a host, the key in the
    /// path and no credentials qualifies; the loopback `http` the local test nodes use is not a
    /// release provider. A fragment is dropped. `scripts/ci/generate-ios-service-configuration.py`
    /// applies the same rules and refuses to generate a build with an unusable value.
    static func providerURL(_ value: String?) -> String? {
        guard let value, let normalized = normalized(value),
              let components = URLComponents(string: normalized),
              components.scheme == "https",
              components.user == nil,
              components.password == nil else {
            return nil
        }
        return normalized
    }

    /// Nodes that answer only a few requests a second per address, and the time the wallet
    /// keeps between two of its requests to each. public.rpc.solanavibestation.com answered
    /// every call spaced 600 ms apart and refused back-to-back calls with HTTP 429 (checked
    /// 2026-10-24).
    static let requestSpacingByHost: [String: TimeInterval] = [
        "public.rpc.solanavibestation.com": 0.65
    ]

    /// The host an expiry proof from `endpoint` counts for: lowercased and without a trailing
    /// dot, port or path, so two spellings of one host, or two paths on it, count once. A
    /// client asked without a node names no host; all such answers count as one.
    static func expiryWitnessHost(for endpoint: String?) -> String {
        guard let endpoint,
              var host = URLComponents(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines))?.host?
              .lowercased() else {
            return ""
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        return host
    }

    /// The time to keep between two requests to `endpoint`; zero for a node without a limit.
    static func requestSpacing(for endpoint: String) -> TimeInterval {
        URLComponents(string: endpoint)?.host.flatMap { requestSpacingByHost[$0.lowercased()] } ?? 0
    }

    static func endpoints(
        for chain: ChainModel,
        network: UniversalWalletRegistry.SolanaNetwork,
        providerURL: String? = configuredProviderURL
    ) -> [String] {
        let isMainnet = network == UniversalWalletRegistry.solanaMainnet
        let registryOrder = (isMainnet ? UniversalWalletRegistry.solanaMainnetRPCURLs : [network.rpcURL])
            .compactMap { normalized($0.absoluteString) }
        let chainNodes = chain.nodes
            .compactMap { normalized($0.url.absoluteString) }
            .sorted { lhs, rhs in
                let lhsRank = registryOrder.firstIndex(of: lhs) ?? registryOrder.count
                let rhsRank = registryOrder.firstIndex(of: rhs) ?? registryOrder.count
                return lhsRank == rhsRank ? lhs < rhs : lhsRank < rhsRank
            }

        let ordered = [isMainnet ? Self.providerURL(providerURL) : nil]
            + [chain.selectedNode.flatMap { normalized($0.url.absoluteString) }]
            + chainNodes
            + (chainNodes.isEmpty ? registryOrder : [])

        return ordered.compactMap { $0 }.reduce(into: [String]()) { result, endpoint in
            if !result.contains(endpoint) {
                result.append(endpoint)
            }
        }
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URLComponents(string: trimmed)?.query == nil else {
            return nil
        }

        return try? SolanaRpcRoutes.normalizeRPCURL(trimmed)
    }
}
