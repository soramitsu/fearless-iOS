@testable import fearless
import XCTest

final class SolanaRpcClientTests: XCTestCase {
    func testPostsValidatedJSONRPCRequestsToConfiguredSolanaRPCEndpoints() async throws {
        let transport = FakeSolanaRpcTransport()
        let client = try SolanaRpcClient(transport: transport, defaultRPCURL: Self.devnetRPC, expectedGenesisHash: UniversalWalletRegistry.solanaDevnet.genesisHash)

        let blockhash = try await client.latestBlockhash(commitment: .finalized)
        let fee = try await client.feeForMessage(Self.transaction, commitment: .confirmed)
        let rent = try await client.minimumBalanceForRentExemption(dataLength: 165, commitment: .processed)
        let accountExists = try await client.accountExists(address: Self.accountAddress, commitment: .finalized)
        let simulation = try await client.simulateTransaction(
            Self.transaction,
            options: SolanaSimulationOptions(commitment: .processed)
        )
        let signature = try await client.sendRawTransaction(
            Self.transaction,
            options: SolanaBroadcastOptions(maxRetries: 3, preflightCommitment: .confirmed, skipPreflight: true)
        )

        XCTAssertEqual(blockhash.value.blockhash, Self.blockhash)
        XCTAssertEqual(blockhash.value.lastValidBlockHeight, 456)
        XCTAssertEqual(fee.value, 5000)
        XCTAssertEqual(rent, 890_880)
        XCTAssertTrue(accountExists)
        XCTAssertEqual(simulation.value.logs, ["Program log: ok"])
        XCTAssertEqual(simulation.value.replacementBlockhash?.blockhash, Self.blockhash)
        XCTAssertEqual(simulation.value.unitsConsumed, 321)
        XCTAssertEqual(signature, Self.signature)
        XCTAssertEqual(
            transport.requestBodies.map { $0["method"] as? String },
            [
                "getLatestBlockhash",
                "getFeeForMessage",
                "getMinimumBalanceForRentExemption",
                "getAccountInfo",
                "simulateTransaction",
                "sendTransaction"
            ]
        )
        XCTAssertEqual(transport.requests.compactMap(\.url?.absoluteString), Array(repeating: Self.devnetRPC, count: 6))
        XCTAssertEqual((transport.requestBodies[0]["params"] as? [[String: Any]])?.first?["commitment"] as? String, "finalized")
        XCTAssertEqual((transport.requestBodies[1]["params"] as? [Any])?.first as? String, Self.transaction)
        XCTAssertEqual((transport.requestBodies[2]["params"] as? [Any])?.first as? Int, 165)
        XCTAssertEqual((transport.requestBodies[3]["params"] as? [Any])?.first as? String, Self.accountAddress)
        XCTAssertEqual(((transport.requestBodies[3]["params"] as? [Any])?[1] as? [String: Any])?["encoding"] as? String, "base64")
        XCTAssertEqual(((transport.requestBodies[4]["params"] as? [Any])?[1] as? [String: Any])?["sigVerify"] as? Bool, false)
        XCTAssertEqual(((transport.requestBodies[5]["params"] as? [Any])?[1] as? [String: Any])?["maxRetries"] as? Int, 3)
    }

    func testRejectsUnsafeURLsMalformedPayloadsAndInvalidOptionsBeforeFetch() async throws {
        XCTAssertThrowsError(try SolanaRpcRoutes.normalizeRPCURL("http://api.mainnet-beta.solana.com")) { error in
            XCTAssertEqual(error as? SolanaRpcClientError, .invalidRPCURL)
        }
        XCTAssertEqual(
            try SolanaRpcRoutes.normalizeRPCURL("http://localhost:8899/?api-key=secret#frag"),
            "http://localhost:8899"
        )

        let transport = FakeSolanaRpcTransport()
        let client = try SolanaRpcClient(transport: transport)

        await assertRpcError(.invalidTransaction) {
            _ = try await client.feeForMessage("not base64")
        }
        await assertRpcError(.invalidDataLength) {
            _ = try await client.minimumBalanceForRentExemption(dataLength: -1)
        }
        await assertRpcError(.invalidDataLength) {
            _ = try await client.minimumBalanceForRentExemption(dataLength: 10_000_001)
        }
        await assertRpcError(.invalidAccountAddress) {
            _ = try await client.accountExists(address: "not-base58")
        }
        await assertRpcError(.invalidSimulationOptions) {
            _ = try await client.simulateTransaction(
                Self.transaction,
                options: SolanaSimulationOptions(replaceRecentBlockhash: true, sigVerify: true)
            )
        }
        await assertRpcError(.invalidMaxRetries) {
            _ = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(maxRetries: 11))
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testMapsRPCErrorsMalformedEnvelopesAndBadResultShapesToTypedErrors() async throws {
        let rpcErrorTransport = FakeSolanaRpcTransport(
            fixedResponse: Self.data("""
            {"jsonrpc":"2.0","id":1,"error":{"code":-32002,"message":"simulation failed","data":{"logs":[]}}}
            """)
        )
        await assertRpcError(.rpcError(SolanaJsonRpcErrorPayload(code: -32002, message: "simulation failed", dataJSON: "{\"logs\":[]}"))) {
            _ = try await SolanaRpcClient(transport: rpcErrorTransport).latestBlockhash()
        }

        let mismatchedId = FakeSolanaRpcTransport(fixedResponse: Self.data(#"{"jsonrpc":"2.0","id":2,"result":{}}"#))
        await assertRpcError(.invalidRPCResponse) {
            _ = try await SolanaRpcClient(transport: mismatchedId).latestBlockhash()
        }

        let badSimulation = FakeSolanaRpcTransport(
            fixedResponse: Self.rpcResponse(id: 1, result: #"{"context":{"slot":1},"value":{"err":null,"logs":[1]}}"#)
        )
        await assertRpcError(.invalidSimulationResponse) {
            _ = try await SolanaRpcClient(transport: badSimulation).simulateTransaction(Self.transaction)
        }

        let badFee = FakeSolanaRpcTransport(
            fixedResponse: Self.rpcResponse(id: 1, result: #"{"context":{"slot":1},"value":-1}"#)
        )
        await assertRpcError(.invalidFeeResponse) {
            _ = try await SolanaRpcClient(transport: badFee).feeForMessage(Self.transaction)
        }

        let unavailableFee = FakeSolanaRpcTransport(
            fixedResponse: Self.rpcResponse(id: 1, result: #"{"context":{"slot":1},"value":null}"#)
        )
        let fee = try await SolanaRpcClient(transport: unavailableFee).feeForMessage(Self.transaction)
        XCTAssertNil(fee.value)

        let badRent = FakeSolanaRpcTransport(fixedResponse: Self.rpcResponse(id: 1, result: #""890880""#))
        await assertRpcError(.invalidRentResponse) {
            _ = try await SolanaRpcClient(transport: badRent).minimumBalanceForRentExemption(dataLength: 165)
        }

        let missingAccount = FakeSolanaRpcTransport(
            fixedResponse: Self.rpcResponse(id: 1, result: #"{"context":{"slot":1},"value":null}"#)
        )
        let accountExists = try await SolanaRpcClient(transport: missingAccount).accountExists(address: Self.accountAddress)
        XCTAssertFalse(accountExists)

        let badAccountInfo = FakeSolanaRpcTransport(
            fixedResponse: Self.rpcResponse(id: 1, result: #"{"context":{"slot":1},"value":[]}"#)
        )
        await assertRpcError(.invalidAccountInfoResponse) {
            _ = try await SolanaRpcClient(transport: badAccountInfo).accountExists(address: Self.accountAddress)
        }

        let badSignature = FakeSolanaRpcTransport(fixedResponse: Self.rpcResponse(id: 1, result: #""not-a-signature""#))
        await assertRpcError(.invalidSignatureResponse) {
            _ = try await SolanaRpcClient(transport: badSignature).sendRawTransaction(Self.transaction)
        }
    }

    // MARK: - Methods added for mainnet sends (IOSUX-4)

    func testEncodesBalanceTokenAccountStatusHeightAndPriorityFeeRequests() async throws {
        let transport = RoutedSolanaTransport { _, method, _ in
            switch method {
            case "getAccountInfo":
                return .success(#"{"context":{"slot":5},"value":{"owner":"11111111111111111111111111111111","lamports":7,"executable":false,"data":["","base64"]}}"#)
            case "getBalance":
                return .success(#"{"context":{"slot":5},"value":2000000000}"#)
            case "getTokenAccountsByOwner":
                return .success(Self.tokenAccountsResult)
            case "getSignatureStatuses":
                return .success(#"{"context":{"slot":5},"value":[null,{"slot":4,"confirmations":null,"err":{"InstructionError":[0,"Custom"]},"confirmationStatus":"finalized"}]}"#)
            case "getBlockHeight":
                return .success("4242")
            case "getRecentPrioritizationFees":
                return .success(#"[{"slot":1,"prioritizationFee":0},{"slot":2,"prioritizationFee":1500}]"#)
            default:
                return .success("null")
            }
        }
        let client = try SolanaRpcClient(transport: transport, defaultRPCURL: Self.devnetRPC, expectedGenesisHash: UniversalWalletRegistry.solanaDevnet.genesisHash)

        let account = try await client.accountInfo(address: Self.accountAddress, commitment: .confirmed)
        let balance = try await client.balance(address: Self.accountAddress, commitment: .confirmed)
        let tokens = try await client.tokenAccountsByOwner(
            owner: Self.owner,
            programId: SolanaTransferTransactionBuilder.splTokenProgramAddress,
            commitment: .confirmed
        )
        let statuses = try await client.signatureStatuses([Self.signature, Self.signature], searchTransactionHistory: true)
        let height = try await client.blockHeight(commitment: .finalized)
        let fees = try await client.recentPrioritizationFees(accounts: [Self.accountAddress])

        XCTAssertEqual(account, SolanaAccountInfo(owner: "11111111111111111111111111111111", lamports: 7, executable: false))
        XCTAssertEqual(balance, 2_000_000_000)
        // A malformed entry, and an account of another token program than the one asked for,
        // are skipped; the other balances stay true.
        XCTAssertEqual(tokens.map(\.address), ["3Mc6vR8ZuxJ7S6oRAQJ8rvxk8nBBWqfnXWDE6QvzgSkd"])
        XCTAssertEqual(tokens.first?.amount, "1250000")
        XCTAssertEqual(tokens.first?.decimals, 6)
        XCTAssertEqual(statuses.first ?? nil, nil)
        XCTAssertEqual(statuses.last??.confirmationStatus, .finalized)
        XCTAssertNotNil(statuses.last??.errorJSON)
        XCTAssertEqual(height, 4242)
        XCTAssertEqual(fees, [0, 1500])

        let accountOptions = (transport.bodies[0]["params"] as? [Any])?[1] as? [String: Any]
        XCTAssertEqual(accountOptions?["dataSlice"] as? [String: Int], ["offset": 0, "length": 0], "Never downloads account data")
        let tokenParams = transport.bodies[2]["params"] as? [Any]
        XCTAssertEqual((tokenParams?[1] as? [String: String])?["programId"], SolanaTransferTransactionBuilder.splTokenProgramAddress)
        XCTAssertEqual((tokenParams?[2] as? [String: Any])?["encoding"] as? String, "jsonParsed")
        XCTAssertEqual(((transport.bodies[3]["params"] as? [Any])?[1] as? [String: Bool])?["searchTransactionHistory"], true)
        XCTAssertEqual(((transport.bodies[4]["params"] as? [Any])?.first as? [String: String])?["commitment"], "finalized")
    }

    // MARK: - Failover across mainnet nodes (IOSUX-4)

    func testFailoverReadsMoveOnFromRateLimitedRefusingAndFailingNodes() async throws {
        let transport = RoutedSolanaTransport { url, _, _ in
            switch url {
            case Self.provider:
                return .failure(UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: nil))
            case Self.mainnetBeta:
                return .failure(UniversalWalletHTTPTransportError.httpStatusCode(403, Data()))
            default:
                return .success(#"{"context":{"slot":9},"value":123}"#)
            }
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        let first = try await client.balance(address: Self.accountAddress, commitment: .confirmed, rpcURL: nil)
        let second = try await client.balance(address: Self.accountAddress, commitment: .confirmed, rpcURL: nil)

        XCTAssertEqual(first, 123)
        XCTAssertEqual(second, 123)
        // The nodes that said no are left alone while they back off.
        XCTAssertEqual(transport.urls, [Self.provider, Self.mainnetBeta, Self.publicNode, Self.publicNode])
    }

    func testFailoverMovesOnFromNodeThatBlocksAMethod() async throws {
        // solana-rpc.publicnode.com answers getTokenAccountsByOwner with HTTP 403 and a JSON-RPC
        // "Request blocked" error (checked 2026-10-11).
        let transport = RoutedSolanaTransport { url, _, id in
            if url == Self.publicNode {
                return .failure(UniversalWalletHTTPTransportError.httpStatusCode(
                    403,
                    Data(#"{"jsonrpc":"2.0","error":{"code":-32602,"message":"Request blocked"},"id":\#(id)}"#.utf8)
                ))
            }
            return .success(Self.tokenAccountsResult)
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.publicNode, Self.mainnetBeta],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        let tokens = try await client.tokenAccountsByOwner(
            owner: Self.owner,
            programId: SolanaTransferTransactionBuilder.splTokenProgramAddress,
            commitment: .confirmed,
            rpcURL: nil
        )

        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(transport.urls, [Self.publicNode, Self.mainnetBeta])
    }

    /// mainnet-beta is rate limiting and publicnode refuses getTokenAccountsByOwner: the
    /// portfolio still shows SOL, and says the token accounts were not read rather than that
    /// there are none. A send's read, which needs the token accounts, still fails.
    func testPortfolioBalances_whenNoNodeServesTokenAccounts_thenSolStillLoads() async throws {
        let transport = RoutedSolanaTransport { url, method, id in
            if url == Self.mainnetBeta {
                return .failure(UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: nil))
            }
            if method == "getTokenAccountsByOwner" {
                return .failure(UniversalWalletHTTPTransportError.httpStatusCode(
                    403,
                    Data(#"{"jsonrpc":"2.0","error":{"code":-32602,"message":"Request blocked"},"id":\#(id)}"#.utf8)
                ))
            }
            return .success(#"{"context":{"slot":9},"value":2500000000}"#)
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )
        let sync = SolanaRpcBalanceSync(rpcClient: client)

        let shown = try await (sync as SolanaBalanceSyncing).portfolioBalances(
            wallet: Self.owner,
            network: UniversalWalletRegistry.solanaMainnet
        )

        XCTAssertEqual(shown.nativeBalance.amount, "2500000000")
        XCTAssertTrue(shown.tokenBalancesUnavailable)
        XCTAssertEqual(shown.tokenBalances, [])
        XCTAssertEqual(shown.balances, [shown.nativeBalance])
        do {
            _ = try await sync.balances(wallet: Self.owner, network: UniversalWalletRegistry.solanaMainnet)
            XCTFail("A send must not mistake unread token accounts for none")
        } catch {
            XCTAssertNotNil(error as? SolanaRpcClientError)
        }
    }

    // MARK: - public.rpc.solanavibestation.com, the node that serves token accounts

    /// mainnet-beta is rate limiting token lookups and publicnode refuses them: both token
    /// programs are read through public.rpc.solanavibestation.com, listed after publicnode,
    /// with the cluster checked before each read and every request to it the node's spacing
    /// after the one before.
    func testTokenAccounts_whenThePublicNodesRefuseThem_thenTheyComeFromSolanaVibeStation() async throws {
        let endpoints = SolanaRpcEndpoints.endpoints(
            for: UniversalWalletRegistry.solanaMainnetChainModel,
            network: UniversalWalletRegistry.solanaMainnet,
            providerURL: nil
        )
        XCTAssertEqual(endpoints, [Self.mainnetBeta, Self.publicNode, Self.vibeStation])
        let clock = PacerClock()
        let transport = TimedSolanaTransport(clock: clock) { url, method, programId in
            Self.realisticPublicNodes(url: url, method: method, programId: programId)
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: endpoints,
            transport: transport,
            health: UniversalWalletEndpointHealth(now: clock.now),
            pacer: clock.pacer
        )

        let shown = try await SolanaRpcBalanceSync(rpcClient: client).balances(
            wallet: Self.owner,
            network: UniversalWalletRegistry.solanaMainnet
        )

        XCTAssertEqual(shown.nativeBalance.amount, "2500000000")
        XCTAssertEqual(Set(shown.tokenBalances.compactMap(\.tokenAccountId)), [Self.splTokenAccount, Self.token2022Account])
        let vibe = transport.requests.filter { $0.url == Self.vibeStation }
        XCTAssertEqual(vibe.map(\.method), ["getGenesisHash", "getTokenAccountsByOwner", "getGenesisHash", "getTokenAccountsByOwner"])
        XCTAssertEqual(vibe.compactMap(\.programId), [
            SolanaTransferTransactionBuilder.splTokenProgramAddress,
            SolanaTransferTransactionBuilder.token2022ProgramAddress
        ])
        for (earlier, later) in zip(vibe, vibe.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later.at - earlier.at, SolanaRpcEndpoints.requestSpacing(for: Self.vibeStation) - 0.000_1)
        }
        XCTAssertEqual(SolanaRpcEndpoints.requestSpacing(for: Self.vibeStation), 0.65)
        XCTAssertEqual(SolanaRpcEndpoints.requestSpacing(for: Self.mainnetBeta), 0)
    }

    /// public.rpc.solanavibestation.com answers a burst with HTTP 429 and an HTML page. Through
    /// the app's own URLSession transport that is a request to slow down, not a bad answer: the
    /// node is asked again after a pause, and both token programs still load.
    func testTokenAccounts_whenSolanaVibeStationAnswers429WithAnHTMLPage_thenBothProgramsStillLoad() async throws {
        let clock = PacerClock()
        let html = Data("<html><head><title>429 Too Many Requests</title></head><body>Too Many Requests</body></html>".utf8)
        var answeredTooMany = false
        SolanaNodeURLProtocol.install(now: clock.elapsed) { url, method, programId, id in
            if url == Self.vibeStation, method == "getTokenAccountsByOwner", !answeredTooMany {
                answeredTooMany = true
                return (429, ["Content-Type": "text/html"], html)
            }
            switch Self.realisticPublicNodes(url: url, method: method, programId: programId) {
            case let .result(result):
                return (200, ["Content-Type": "application/json"], Self.rpcResponse(id: id, result: result))
            case let .rpcError(status, error):
                return (status, ["Content-Type": "application/json"], Self.data(#"{"jsonrpc":"2.0","id":\#(id),"error":\#(error)}"#))
            }
        }
        defer { SolanaNodeURLProtocol.uninstall() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SolanaNodeURLProtocol.self]
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.mainnetBeta, Self.publicNode, Self.vibeStation],
            transport: URLSessionUniversalWalletHTTPTransport(session: URLSession(configuration: configuration)),
            health: UniversalWalletEndpointHealth(now: clock.now),
            pacer: clock.pacer
        )

        let shown = try await SolanaRpcBalanceSync(rpcClient: client).portfolioBalances(
            wallet: Self.owner,
            network: UniversalWalletRegistry.solanaMainnet,
            rpcURL: nil
        )

        XCTAssertFalse(shown.tokenBalancesUnavailable)
        XCTAssertEqual(Set(shown.tokenBalances.compactMap(\.tokenAccountId)), [Self.splTokenAccount, Self.token2022Account])
        let vibe = SolanaNodeURLProtocol.requests.filter { $0.url == Self.vibeStation }
        XCTAssertEqual(vibe.map(\.method), [
            "getGenesisHash", "getTokenAccountsByOwner",
            "getGenesisHash", "getTokenAccountsByOwner",
            "getGenesisHash", "getTokenAccountsByOwner"
        ])
        XCTAssertGreaterThanOrEqual(vibe[2].at - vibe[1].at, SolanaRpcRequestPacer.rateLimitPause - 0.000_1, "Asked again only after a pause")
    }

    /// SOL does not wait on the token accounts or on the node that serves them: it is read
    /// from the first node at once, and still shown when every token read is refused.
    func testSol_whenEveryTokenReadIsRefused_thenSolIsStillReadAtOnce() async throws {
        let clock = PacerClock()
        let transport = TimedSolanaTransport(clock: clock) { url, method, programId in
            if url == Self.vibeStation, method == "getTokenAccountsByOwner" {
                return .rpcError(429, "")
            }
            return Self.realisticPublicNodes(url: url, method: method, programId: programId)
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.mainnetBeta, Self.publicNode, Self.vibeStation],
            transport: transport,
            health: UniversalWalletEndpointHealth(now: clock.now),
            pacer: clock.pacer
        )
        let sync = SolanaRpcBalanceSync(rpcClient: client)

        let shown = try await sync.portfolioBalances(wallet: Self.owner, network: UniversalWalletRegistry.solanaMainnet, rpcURL: nil)

        XCTAssertEqual(shown.nativeBalance.amount, "2500000000")
        XCTAssertTrue(shown.tokenBalancesUnavailable)
        XCTAssertEqual(shown.tokenBalances, [])
        let solRead = try XCTUnwrap(transport.requests.first { $0.method == "getBalance" })
        XCTAssertEqual(solRead.url, Self.mainnetBeta)
        XCTAssertEqual(solRead.at, 0, "SOL waited for nothing")
        do {
            _ = try await sync.balances(wallet: Self.owner, network: UniversalWalletRegistry.solanaMainnet)
            XCTFail("A send must not mistake unread token accounts for none")
        } catch {
            XCTAssertEqual(error as? SolanaRpcClientError, .httpStatusCode(429))
        }
    }

    /// Requests to a rate-limited node wait their turn, each the node's spacing after the last,
    /// and the first after "too many requests" waits for the pause; other nodes never wait.
    func testPacer_spacesRequestsToARateLimitedNodeOnly() async throws {
        let clock = PacerClock()
        let spacing = SolanaRpcEndpoints.requestSpacing(for: Self.vibeStation)
        var turns: [TimeInterval] = []
        for _ in 0 ..< 3 {
            try await clock.pacer.waitForTurn(Self.vibeStation, spacing: spacing)
            turns.append(clock.elapsed())
        }
        XCTAssertEqual(turns.count, 3)
        XCTAssertEqual(turns[0], 0, accuracy: 0.000_1)
        XCTAssertEqual(turns[1], spacing, accuracy: 0.000_1)
        XCTAssertEqual(turns[2], 2 * spacing, accuracy: 0.000_1)

        try await clock.pacer.waitForTurn(Self.mainnetBeta, spacing: SolanaRpcEndpoints.requestSpacing(for: Self.mainnetBeta))
        XCTAssertEqual(clock.elapsed(), 2 * spacing, accuracy: 0.000_1, "A node without a limit is never held up")

        clock.pacer.holdBack(Self.vibeStation, for: SolanaRpcRequestPacer.rateLimitPause)
        try await clock.pacer.waitForTurn(Self.vibeStation, spacing: spacing)
        XCTAssertEqual(clock.elapsed(), 2 * spacing + SolanaRpcRequestPacer.rateLimitPause, accuracy: 0.000_1)
    }

    /// What the public nodes answered on 2026-10-24: mainnet-beta serves SOL but rate limits
    /// token lookups, publicnode refuses them with HTTP 403 "Request blocked", and
    /// public.rpc.solanavibestation.com serves both token programs.
    private static func realisticPublicNodes(url: String, method: String, programId: String?) -> NodeAnswer {
        switch (url, method) {
        case (_, "getBalance"):
            return .result(#"{"context":{"slot":9},"value":2500000000}"#)
        case (Self.mainnetBeta, "getTokenAccountsByOwner"):
            return .rpcError(429, "")
        case (Self.publicNode, "getTokenAccountsByOwner"):
            return .rpcError(403, #"{"code":-32602,"message":"Request blocked"}"#)
        case (Self.vibeStation, "getTokenAccountsByOwner"):
            return .result(programId == SolanaTransferTransactionBuilder.token2022ProgramAddress
                ? Self.token2022AccountResult
                : Self.splAccountResult)
        default:
            return .rpcError(500, "")
        }
    }

    private static let splTokenAccount = "3Mc6vR8ZuxJ7S6oRAQJ8rvxk8nBBWqfnXWDE6QvzgSkd"
    private static let token2022Account = "5N3f1tj9v1vc5TUZ8S7mCAnVmjVKrfnzXWhxLaxyZAgt"
    private static let splAccountResult = #"""
    {"context":{"slot":5},"value":[
      {"pubkey":"3Mc6vR8ZuxJ7S6oRAQJ8rvxk8nBBWqfnXWDE6QvzgSkd","account":{"owner":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA","lamports":2039280,"executable":false,
        "data":{"program":"spl-token","space":165,"parsed":{"type":"account","info":{"mint":"EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v","owner":"HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk","state":"initialized","isNative":false,
          "tokenAmount":{"amount":"1250000","decimals":6,"uiAmountString":"1.25"}}}}}}
    ]}
    """#
    private static let token2022AccountResult = #"""
    {"context":{"slot":5},"value":[
      {"pubkey":"5N3f1tj9v1vc5TUZ8S7mCAnVmjVKrfnzXWhxLaxyZAgt","account":{"owner":"TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb","lamports":2039280,"executable":false,
        "data":{"program":"spl-token-2022","space":165,"parsed":{"type":"account","info":{"mint":"2b1kV6DkPAnxd5ixfnxCpjxmKwqjjaYmCZfHsFu24GXo","owner":"HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk","state":"initialized","isNative":false,
          "tokenAmount":{"amount":"5000000","decimals":6,"uiAmountString":"5"}}}}}}
    ]}
    """#

    fileprivate enum NodeAnswer {
        case result(String)
        /// An HTTP status with a JSON-RPC error object (empty for a bare status).
        case rpcError(Int, String)
    }

    /// Virtual time for the pacer and the backoff: waiting moves the clock, nothing sleeps.
    private final class PacerClock {
        private let lock = NSLock()
        private var current = Date(timeIntervalSince1970: 2_000_000_000)
        private let start = Date(timeIntervalSince1970: 2_000_000_000)

        func now() -> Date {
            lock.lock()
            defer { lock.unlock() }
            return current
        }

        func elapsed() -> TimeInterval {
            now().timeIntervalSince(start)
        }

        func advance(_ seconds: TimeInterval) {
            lock.lock()
            current = current.addingTimeInterval(max(0, seconds))
            lock.unlock()
        }

        lazy var pacer = SolanaRpcRequestPacer(
            now: { [unowned self] in self.now() },
            sleep: { [unowned self] seconds in self.advance(seconds) }
        )
    }

    /// Answers each node per method, records every request (the cluster checks too) with the
    /// virtual time it was sent at.
    private final class TimedSolanaTransport: UniversalWalletHTTPTransport {
        struct Request {
            let url: String
            let method: String
            let programId: String?
            let at: TimeInterval
        }

        private let clock: PacerClock
        private let route: (String, String, String?) -> NodeAnswer
        private let lock = NSLock()
        private var recorded: [Request] = []

        init(clock: PacerClock, route: @escaping (_ url: String, _ method: String, _ programId: String?) -> NodeAnswer) {
            self.clock = clock
            self.route = route
        }

        var requests: [Request] {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }

        func perform(_ request: URLRequest) async throws -> Data {
            let url = request.url?.absoluteString ?? ""
            let body = try (request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] }) ?? [:]
            let id = body["id"] as? Int ?? 0
            let method = body["method"] as? String ?? ""
            let programId = ((body["params"] as? [Any])?.dropFirst().first as? [String: Any])?["programId"] as? String
            lock.lock()
            recorded.append(Request(url: url, method: method, programId: programId, at: clock.elapsed()))
            lock.unlock()
            if method == "getGenesisHash" {
                return SolanaRpcClientTests.rpcResponse(id: id, result: "\"\(UniversalWalletRegistry.solanaMainnet.genesisHash)\"")
            }
            switch route(url, method, programId) {
            case let .result(result):
                return SolanaRpcClientTests.rpcResponse(id: id, result: result)
            case .rpcError(429, _):
                throw UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: nil)
            case let .rpcError(status, error):
                let payload = error.isEmpty ? Data() : SolanaRpcClientTests.data(#"{"jsonrpc":"2.0","id":\#(id),"error":\#(error)}"#)
                throw UniversalWalletHTTPTransportError.httpStatusCode(status, payload)
            }
        }
    }

    func testFailoverStillAsksEveryNodeWhenAllAreBackingOff() async throws {
        var failing = true
        let transport = RoutedSolanaTransport { _, _, _ in
            failing ? .failure(UniversalWalletHTTPTransportError.httpStatusCode(502, Data())) : .success("650240")
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        await assertFailoverError(.httpStatusCode(502)) {
            _ = try await client.minimumBalanceForRentExemption(dataLength: 0, commitment: .confirmed, rpcURL: nil)
        }
        failing = false
        let rent = try await client.minimumBalanceForRentExemption(dataLength: 0, commitment: .confirmed, rpcURL: nil)

        XCTAssertEqual(rent, 650_240)
        XCTAssertEqual(transport.urls, [Self.mainnetBeta, Self.publicNode, Self.mainnetBeta])
    }

    func testFailoverNeverRetriesARequestTheWalletItselfRejected() async throws {
        let transport = RoutedSolanaTransport { _, _, _ in .success("null") }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        await assertFailoverError(.invalidAccountAddress) {
            _ = try await client.balance(address: "not-base58", commitment: .confirmed, rpcURL: nil)
        }
        XCTAssertTrue(transport.urls.isEmpty)
    }

    func testFailoverStartsAtTheNamedNodeAndKeepsAForeignNodeAlone() async throws {
        let transport = RoutedSolanaTransport { url, _, _ in
            url == Self.mainnetBeta
                ? .success("1")
                : .failure(URLError(.cannotConnectToHost))
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        _ = try await client.blockHeight(commitment: .confirmed, rpcURL: Self.publicNode)
        await assertFailoverError(nil) {
            _ = try await client.blockHeight(commitment: .confirmed, rpcURL: "http://127.0.0.1:1")
        }

        XCTAssertEqual(transport.urls, [Self.publicNode, Self.mainnetBeta, "http://127.0.0.1:1"])
    }

    func testBroadcastOffersTheSameBytesToEachNodeUntilOneAccepts() async throws {
        let transport = RoutedSolanaTransport { url, _, _ in
            switch url {
            case Self.provider:
                return .failure(URLError(.timedOut))
            case Self.mainnetBeta:
                return .success(#"null"#, error: #"{"code":-32005,"message":"Node is behind"}"#)
            default:
                return .success(#""\#(Self.signature)""#)
            }
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        let signature = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(), rpcURL: nil)

        XCTAssertEqual(signature, Self.signature)
        XCTAssertEqual(transport.urls, [Self.provider, Self.mainnetBeta, Self.publicNode])
        XCTAssertEqual(Set(transport.bodies.compactMap { ($0["params"] as? [Any])?.first as? String }), [Self.transaction])
    }

    func testBroadcastFailureSaysHowEachNodeAnswered() async throws {
        let transport = RoutedSolanaTransport { url, _, _ in
            switch url {
            case Self.provider:
                return .failure(UniversalWalletHTTPTransportError.httpStatusCode(403, Data()))
            case Self.mainnetBeta:
                return .failure(UniversalWalletHTTPTransportError.httpStatusCode(502, Data()))
            default:
                return .success("null", error: #"{"code":-32002,"message":"Transaction simulation failed"}"#)
            }
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        do {
            _ = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(), rpcURL: nil)
            XCTFail("Expected every node to refuse")
        } catch let failure as SolanaBroadcastFailure {
            XCTAssertEqual(failure.attempts, [
                .notSent,
                .ambiguous,
                .refused(SolanaJsonRpcErrorPayload(code: -32002, message: "Transaction simulation failed", dataJSON: nil))
            ])
            XCTAssertTrue(failure.mayHaveReachedCluster, "A 502 may have forwarded it")
            XCTAssertTrue(failure.someNodeRefused)
        }
    }

    func testBroadcastAttemptOutcomes() {
        let payload = SolanaJsonRpcErrorPayload(code: -32003, message: "signature verification failure", dataJSON: nil)
        let cases: [(Error, SolanaBroadcastAttemptOutcome)] = [
            (SolanaRpcClientError.httpStatusCode(401), .notSent),
            (SolanaRpcClientError.httpStatusCode(403), .notSent),
            (SolanaRpcClientError.httpStatusCode(429), .notSent),
            (SolanaRpcClientError.httpStatusCode(500), .ambiguous),
            (SolanaRpcClientError.httpStatusCode(504), .ambiguous),
            (SolanaRpcClientError.rpcError(payload), .refused(payload)),
            (SolanaRpcClientError.rpcError(SolanaJsonRpcErrorPayload(code: -32603, message: "internal", dataJSON: nil)), .ambiguous),
            (SolanaRpcClientError.invalidRPCResponse, .ambiguous),
            (SolanaRpcClientError.invalidSignatureResponse, .ambiguous),
            (URLError(.notConnectedToInternet), .notSent),
            (URLError(.cannotFindHost), .notSent),
            (URLError(.serverCertificateUntrusted), .notSent),
            (URLError(.timedOut), .ambiguous),
            (URLError(.networkConnectionLost), .ambiguous),
            (CocoaError(.featureUnsupported), .ambiguous)
        ]
        for (error, expected) in cases {
            XCTAssertEqual(SolanaBroadcastAttemptOutcome(error: error), expected, "\(error)")
        }
        XCTAssertTrue(SolanaBroadcastFailure(attempts: []).mayHaveReachedCluster, "No answer at all proves nothing")
        XCTAssertFalse(SolanaBroadcastFailure(attempts: [.notSent, .refused(nil)]).mayHaveReachedCluster)
    }

    /// Only a short list of JSON-RPC codes says what a node did with the transaction before
    /// relaying anything. Every other code may follow a relay.
    func testBroadcastAttemptOutcomes_forEveryJSONRPCCode() {
        func outcome(_ code: Int) -> SolanaBroadcastAttemptOutcome {
            SolanaBroadcastAttemptOutcome(error: SolanaRpcClientError.rpcError(
                SolanaJsonRpcErrorPayload(code: code, message: "fixture", dataJSON: nil)
            ))
        }
        for code in [-32002, -32003, -32600, -32602, -32700] {
            XCTAssertEqual(outcome(code), .refused(SolanaJsonRpcErrorPayload(code: code, message: "fixture", dataJSON: nil)), "\(code)")
        }
        for code in [-32601, -32004, -32005, -32014, -32016] {
            XCTAssertEqual(outcome(code), .notSent, "\(code) cannot take it: the next node is asked")
        }
        for code in [-32603, -32000, -32001, -32007, -32099, -32403, -32429, -32604, -1, 0, 1, 429, 32002] {
            XCTAssertEqual(outcome(code), .ambiguous, "\(code) may follow a relay")
        }
    }

    /// A node that answers with a code that may follow a relay may have forwarded the payment.
    /// The next node gets the same bytes, without a simulation that would only see that copy.
    func testBroadcast_whenANodeMayHaveRelayedIt_thenTheNextGetsTheSameBytesWithoutASimulation() async throws {
        for code in [-32603, -32000, -32001, -32429] {
            let transport = RoutedSolanaTransport { url, _, _ in
                url == Self.provider
                    ? .success("null", error: #"{"code":\#(code),"message":"fixture"}"#)
                    : .success(#""\#(Self.signature)""#)
            }
            let client = try SolanaFailoverRpcClient(
                endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
                transport: transport,
                health: UniversalWalletEndpointHealth()
            )

            let signature = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(), rpcURL: nil)

            XCTAssertEqual(signature, Self.signature, "\(code)")
            XCTAssertEqual(transport.urls, [Self.provider, Self.mainnetBeta], "\(code)")
            XCTAssertEqual(Self.sentTransactions(transport), [Self.transaction, Self.transaction], "\(code)")
            XCTAssertEqual(Self.skippedPreflight(transport), [false, true], "\(code)")
        }
    }

    /// When no node accepts bytes that one of them may have relayed, the failure says so and
    /// claims no refusal: only the chain can tell whether the payment went out.
    func testBroadcast_whenEveryNodeMayHaveRelayedIt_thenTheFailureSaysSoAndNoNodeRefused() async throws {
        let codes = [Self.provider: -32603, Self.mainnetBeta: -32000, Self.publicNode: -32429]
        let transport = RoutedSolanaTransport { url, _, _ in
            .success("null", error: #"{"code":\#(codes[url] ?? -32001),"message":"fixture"}"#)
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        do {
            _ = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(), rpcURL: nil)
            XCTFail("Expected no node to accept it")
        } catch let failure as SolanaBroadcastFailure {
            XCTAssertEqual(failure.attempts, [.ambiguous, .ambiguous, .ambiguous])
            XCTAssertTrue(failure.mayHaveReachedCluster)
            XCTAssertFalse(failure.someNodeRefused)
        }
        XCTAssertEqual(transport.urls, [Self.provider, Self.mainnetBeta, Self.publicNode])
        XCTAssertEqual(Self.sentTransactions(transport), Array(repeating: Self.transaction, count: 3))
        XCTAssertEqual(Self.skippedPreflight(transport), [false, true, true])
    }

    /// A node that judged the transaction before relaying it (a failed simulation, a bad
    /// signature, bytes it could not decode) has answered for every node: none is asked again.
    func testBroadcast_whenTheFirstNodeJudgesTheTransaction_thenNoOtherNodeIsAsked() async throws {
        for code in [-32002, -32003, -32600, -32602, -32700] {
            let transport = RoutedSolanaTransport { url, _, _ in
                url == Self.provider
                    ? .success("null", error: #"{"code":\#(code),"message":"fixture"}"#)
                    : .success(#""\#(Self.signature)""#)
            }
            let client = try SolanaFailoverRpcClient(
                endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
                transport: transport,
                health: UniversalWalletEndpointHealth()
            )

            do {
                _ = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(), rpcURL: nil)
                XCTFail("Expected the refusal to stand: \(code)")
            } catch let failure as SolanaBroadcastFailure {
                XCTAssertEqual(failure.attempts, [.refused(SolanaJsonRpcErrorPayload(code: code, message: "fixture", dataJSON: nil))])
                XCTAssertFalse(failure.mayHaveReachedCluster, "\(code)")
                XCTAssertTrue(failure.someNodeRefused, "\(code)")
            }
            XCTAssertEqual(transport.urls, [Self.provider], "\(code)")
        }
    }

    /// A node that cannot take a transaction (no such method, behind) relayed nothing: the next
    /// node is asked, with its simulation, and if none can, nothing went out.
    func testBroadcast_whenANodeCannotTakeIt_thenTheNextIsAskedAndNothingWentOut() async throws {
        for code in [-32601, -32004, -32005, -32014, -32016] {
            let transport = RoutedSolanaTransport { url, _, _ in
                url == Self.publicNode
                    ? .success(#""\#(Self.signature)""#)
                    : .success("null", error: #"{"code":\#(code),"message":"fixture"}"#)
            }
            let client = try SolanaFailoverRpcClient(
                endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
                transport: transport,
                health: UniversalWalletEndpointHealth()
            )

            let signature = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(), rpcURL: nil)

            XCTAssertEqual(signature, Self.signature, "\(code)")
            XCTAssertEqual(transport.urls, [Self.provider, Self.mainnetBeta, Self.publicNode], "\(code)")
            XCTAssertEqual(Self.skippedPreflight(transport), [false, false, false], "\(code)")
        }

        let transport = RoutedSolanaTransport { _, _, _ in .success("null", error: #"{"code":-32005,"message":"Node is behind"}"#) }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.provider, Self.mainnetBeta],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )
        do {
            _ = try await client.sendRawTransaction(Self.transaction, options: SolanaBroadcastOptions(), rpcURL: nil)
            XCTFail("Expected no node to take it")
        } catch let failure as SolanaBroadcastFailure {
            XCTAssertEqual(failure.attempts, [.notSent, .notSent])
            XCTAssertFalse(failure.mayHaveReachedCluster)
            XCTAssertFalse(failure.someNodeRefused)
        }
    }

    private static func sentTransactions(_ transport: RoutedSolanaTransport) -> [String] {
        transport.bodies.filter { $0["method"] as? String == "sendTransaction" }.compactMap { ($0["params"] as? [Any])?.first as? String }
    }

    private static func skippedPreflight(_ transport: RoutedSolanaTransport) -> [Bool] {
        transport.bodies.filter { $0["method"] as? String == "sendTransaction" }.map {
            (($0["params"] as? [Any])?.last as? [String: Any])?["skipPreflight"] as? Bool ?? false
        }
    }

    func testSignatureStatusesTakeTheMostConfirmedAnswerOfAnyNode() async throws {
        let transport = RoutedSolanaTransport { url, _, _ in
            switch url {
            case Self.provider:
                return .failure(URLError(.cannotConnectToHost))
            case Self.mainnetBeta:
                return .success(#"{"context":{"slot":9},"value":[null,{"slot":8,"err":null,"confirmationStatus":"processed"}]}"#)
            default:
                return .success(#"{"context":{"slot":9},"value":[{"slot":7,"err":null,"confirmationStatus":"confirmed"},null]}"#)
            }
        }
        let client = try SolanaFailoverRpcClient(
            endpoints: [Self.provider, Self.mainnetBeta, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )

        let statuses = try await client.signatureStatuses([Self.signature, Self.signature], searchTransactionHistory: true, rpcURL: nil)

        XCTAssertEqual(statuses.map { $0?.confirmationStatus }, [.confirmed, .processed])
        XCTAssertEqual(transport.urls, [Self.provider, Self.mainnetBeta, Self.publicNode])
    }

    func testResolveSignatureNeedsANodeThatProvesExpiryAndAnySightingWins() async throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: Self.owner,
            recipientAddress: Self.accountAddress, lamports: 1, recentBlockhash: Self.blockhash)
        let transaction = try SolanaTransactionSigner.parseSerializedTransaction(base64: unsigned.transactionBase64)
        func client(_ answers: [String: (valid: Bool, status: String)]) throws -> SolanaFailoverRpcClient {
            try SolanaFailoverRpcClient(endpoints: [Self.mainnetBeta, Self.publicNode],
                transport: RoutedSolanaTransport { url, method, _ in
                    guard let answer = answers[url] else { return .failure(URLError(.cannotConnectToHost)) }
                    switch method {
                    case "getBlock": return .success("{\"blockhash\":\"\(Self.blockhash)\"}")
                    case "isBlockhashValid": return .success("{\"context\":{\"slot\":1001},\"value\":\(answer.valid)}")
                    default: return .success("{\"context\":{\"slot\":1001},\"value\":[\(answer.status)]}")
                    }
                }, health: UniversalWalletEndpointHealth())
        }
        let seen = #"{"slot":3,"err":null,"confirmationStatus":"confirmed"}"#
        let expiredThenSeen = try await client([Self.mainnetBeta: (false, "null"), Self.publicNode: (false, seen)])
            .resolveSignature(Self.signature, transaction: transaction, blockhashContextSlot: 100, rpcURL: nil)
        let expiredAndLive = try await client([Self.mainnetBeta: (false, "null"), Self.publicNode: (true, "null")])
            .resolveSignature(Self.signature, transaction: transaction, blockhashContextSlot: 100, rpcURL: nil)
        let bothExpired = try await client([Self.mainnetBeta: (false, "null"), Self.publicNode: (false, "null")])
            .resolveSignature(Self.signature, transaction: transaction, blockhashContextSlot: 100, rpcURL: nil)
        let oneUnreachable = try await client([Self.publicNode: (true, "null")])
            .resolveSignature(Self.signature, transaction: transaction, blockhashContextSlot: 100, rpcURL: nil)
        if case .landed = expiredThenSeen {} else { XCTFail("A positive status wins: \(expiredThenSeen)") }
        XCTAssertEqual(expiredAndLive, .pending, "One live endpoint vetoes an expiry assertion")
        XCTAssertEqual(bothExpired, .expired(provingHosts: ["api.mainnet-beta.solana.com", "solana-rpc.publicnode.com"]))
        XCTAssertEqual(oneUnreachable, .pending)
        do {
            _ = try await client([:]).resolveSignature(Self.signature, transaction: transaction, blockhashContextSlot: 100, rpcURL: nil)
            XCTFail("No node answered; nothing may be concluded")
        } catch {}
    }

    /// An expiry counts each host that proved it once: lowercased, without a trailing dot, port
    /// or path. One host's backend may lack the slot's history, so one host is one witness
    /// however many of its endpoints answered.
    func testResolveSignature_countsEachHostThatProvesExpiryOnce() async throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: Self.owner,
            recipientAddress: Self.accountAddress, lamports: 1, recentBlockhash: Self.blockhash)
        let transaction = try SolanaTransactionSigner.parseSerializedTransaction(base64: unsigned.transactionBase64)
        /// `answer` says, per requested URL, whether its blockhash is still valid; nil: no answer.
        func resolve(_ endpoints: [String], _ answer: @escaping (String) -> Bool?) async throws -> SolanaSignatureResolution {
            let client = try SolanaFailoverRpcClient(endpoints: endpoints, transport: RoutedSolanaTransport { url, method, _ in
                guard let valid = answer(url) else { return .failure(URLError(.cannotConnectToHost)) }
                switch method {
                case "getBlock": return .success("{\"blockhash\":\"\(Self.blockhash)\"}")
                case "isBlockhashValid": return .success("{\"context\":{\"slot\":1001},\"value\":\(valid)}")
                default: return .success("{\"context\":{\"slot\":1001},\"value\":[null]}")
                }
            }, health: UniversalWalletEndpointHealth())
            return try await client.resolveSignature(Self.signature, transaction: transaction, blockhashContextSlot: 100, rpcURL: nil)
        }
        let mainnetBetaHost = "api.mainnet-beta.solana.com"

        let alone = try await resolve([Self.mainnetBeta, Self.publicNode, Self.provider]) { url in
            url.hasPrefix(Self.mainnetBeta) ? false : nil
        }
        XCTAssertEqual(alone, .expired(provingHosts: [mainnetBetaHost]), "One host proved it; the others did not answer")

        let spellings = try await resolve([
            "https://API.Mainnet-Beta.Solana.com", "https://api.mainnet-beta.solana.com./", "https://api.mainnet-beta.solana.com/rpc"
        ]) { _ in false }
        XCTAssertEqual(spellings, .expired(provingHosts: [mainnetBetaHost]), "Three endpoints on one host are one witness")

        let distinct = try await resolve([Self.mainnetBeta, Self.publicNode]) { _ in false }
        XCTAssertEqual(distinct, .expired(provingHosts: [mainnetBetaHost, "solana-rpc.publicnode.com"]))

        let vetoed = try await resolve([Self.mainnetBeta, Self.publicNode]) { url in url.hasPrefix(Self.mainnetBeta) ? false : true }
        XCTAssertEqual(vetoed, .pending, "A node that still accepts the blockhash vetoes the other's proof")

        XCTAssertEqual(SolanaRpcEndpoints.expiryWitnessHost(for: "HTTPS://API.Mainnet-Beta.Solana.COM.:443/x"), mainnetBetaHost)
        XCTAssertEqual(
            SolanaRpcEndpoints.expiryWitnessHost(for: "http://127.0.0.1:8899/svc/a-primary"),
            SolanaRpcEndpoints.expiryWitnessHost(for: "http://127.0.0.1:8899/svc/b-secondary"),
            "Two services behind one local proxy are one host"
        )
        XCTAssertEqual(SolanaRpcEndpoints.expiryWitnessHost(for: nil), "")
    }

    func testConcurrentRequestsThroughOneClientGetDistinctIds() async throws {
        let transport = EchoingHeightTransport()
        let client = try SolanaRpcClient(transport: transport, defaultRPCURL: Self.devnetRPC, expectedGenesisHash: UniversalWalletRegistry.solanaDevnet.genesisHash)

        let heights = try await withThrowingTaskGroup(of: Int64.self) { group in
            for _ in 0 ..< 64 {
                group.addTask { try await client.blockHeight(commitment: .confirmed) }
            }
            return try await group.reduce(into: [Int64]()) { $0.append($1) }
        }

        XCTAssertEqual(heights.count, 64)
        XCTAssertEqual(Set(transport.ids).count, 128, "The 64 fresh genesis assertions and 64 reads all carry distinct ids")
    }

    func testMainnetNodesAreTheProviderThenPublicJSONRPCNeverTheIndexer() {
        let mainnet = UniversalWalletRegistry.solanaMainnetChainModel
        let provider = "https://solana-mainnet.example-provider.com/v2/key123"

        XCTAssertEqual(
            SolanaRpcEndpoints.endpoints(for: mainnet, network: UniversalWalletRegistry.solanaMainnet, providerURL: provider),
            [provider, Self.mainnetBeta, Self.publicNode, Self.vibeStation]
        )
        XCTAssertEqual(
            SolanaRpcEndpoints.endpoints(for: mainnet, network: UniversalWalletRegistry.solanaMainnet, providerURL: nil),
            [Self.mainnetBeta, Self.publicNode, Self.vibeStation]
        )
        // A key in a query string would be dropped by the client, so such a provider is ignored,
        // as is anything that is not https.
        for unusable in ["https://rpc.example.com/?api-key=secret", "http://rpc.example.com", "", "   "] {
            XCTAssertEqual(
                SolanaRpcEndpoints.endpoints(for: mainnet, network: UniversalWalletRegistry.solanaMainnet, providerURL: unusable),
                [Self.mainnetBeta, Self.publicNode, Self.vibeStation],
                unusable
            )
        }
        // The build's mainnet provider is never used for another cluster.
        let devnet = ChainModel(
            rank: nil,
            disabled: false,
            chainId: UniversalWalletRegistry.solanaDevnet.chainId,
            parentId: nil,
            paraId: nil,
            name: "Solana Devnet",
            assets: [],
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: [.testnet],
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        XCTAssertEqual(
            SolanaRpcEndpoints.endpoints(for: devnet, network: UniversalWalletRegistry.solanaDevnet, providerURL: provider),
            [Self.devnetRPC]
        )
        XCTAssertEqual(SolanaFailoverRpcClient.mainnet?.endpoints, [Self.mainnetBeta, Self.publicNode, Self.vibeStation])
        XCTAssertFalse(
            (SolanaFailoverRpcClient.mainnet?.endpoints ?? []).contains { $0.contains("soramitsu") },
            "Mainnet never depends on the SORA indexer, which serves testnet"
        )
        XCTAssertEqual(Set(mainnet.nodes.map(\.url.absoluteString)), [Self.mainnetBeta, Self.publicNode, Self.vibeStation])
    }

    /// FL_SOLANA_RPC_URL is optional. A build without it, or with a value the wallet cannot
    /// use, reads and broadcasts through the public nodes alone and never fails to start.
    func testOptionalProvider_whenAbsentOrUnusable_thenThePublicNodesServeAlone() throws {
        let mainnet = UniversalWalletRegistry.solanaMainnetChainModel
        let unusable: [String?] = [
            nil, "", "   ", "not a url", "https://", "https:///v2/key", "https://:443",
            "ftp://rpc.example.com", "http://rpc.example.com/v2/key", "http://127.0.0.1:8899",
            "http://localhost:8899", "javascript:alert(1)", "https://rpc.example.com/?api-key=secret",
            "https://rpc.example.com/v2/key?", "https://rpc.example.com:port/v2/key",
            "\"https://rpc.example.com/v2/key\"", "https://user:password@rpc.example.com/v2/key",
            "https://user@rpc.example.com/v2/key"
        ]

        for value in unusable {
            XCTAssertNil(SolanaRpcEndpoints.providerURL(value), String(describing: value))
            let endpoints = SolanaRpcEndpoints.endpoints(
                for: mainnet,
                network: UniversalWalletRegistry.solanaMainnet,
                providerURL: value
            )
            XCTAssertEqual(endpoints, [Self.mainnetBeta, Self.publicNode, Self.vibeStation], String(describing: value))
            XCTAssertEqual(try SolanaFailoverRpcClient(endpoints: endpoints).endpoints, endpoints)
        }

        // Usable forms: surrounding whitespace and a trailing slash are trimmed, scheme and host
        // are case-insensitive (the key in the path keeps its case), a fragment is dropped.
        let usable: [(String, String)] = [
            ("  https://solana-mainnet.example-provider.com/v2/key123/ \n", "https://solana-mainnet.example-provider.com/v2/key123"),
            ("HTTPS://Solana-Mainnet.Example-Provider.com/v2/KeyABC", "https://solana-mainnet.example-provider.com/v2/KeyABC"),
            ("https://solana-mainnet.example-provider.com/v2/key123#section", "https://solana-mainnet.example-provider.com/v2/key123"),
            ("https://solana-mainnet.example-provider.com:8443/v2/key123", "https://solana-mainnet.example-provider.com:8443/v2/key123")
        ]
        for (value, expected) in usable {
            XCTAssertEqual(SolanaRpcEndpoints.providerURL(value), expected, value)
            XCTAssertEqual(
                SolanaRpcEndpoints.endpoints(for: mainnet, network: UniversalWalletRegistry.solanaMainnet, providerURL: value),
                [expected, Self.mainnetBeta, Self.publicNode, Self.vibeStation],
                value
            )
        }
        // Whatever the build was given, the app's shared clients exist and end with the public nodes.
        XCTAssertEqual(
            SolanaFailoverRpcClient.mainnet.map { Array($0.endpoints.suffix(3)) },
            [Self.mainnetBeta, Self.publicNode, Self.vibeStation]
        )
        XCTAssertNotNil(SolanaRpcBalanceSync.mainnet)
        // A node address without a host is refused before any request is made.
        for value in ["https://", "https:///v2/key", "https://:443"] {
            XCTAssertThrowsError(try SolanaRpcRoutes.normalizeRPCURL(value), value) { error in
                XCTAssertEqual(error as? SolanaRpcClientError, .invalidRPCURL)
            }
        }
    }

    /// A provider URL carries its key in the path, and URLError keeps the URL it failed on in its
    /// user info. Nothing written to the log may carry either.
    func testLogSafeDescription_neverCarriesANodeURLOrItsKey() throws {
        let keyed = "https://solana-mainnet.example-provider.com/v2/secret-key-123"
        let url = try XCTUnwrap(URL(string: keyed))
        let urlError = URLError(.timedOut, userInfo: [
            NSURLErrorFailingURLStringErrorKey: keyed,
            NSURLErrorFailingURLErrorKey: url
        ])
        XCTAssertTrue("\(urlError)".contains("secret-key-123"), "The plain description does carry the key")

        let errors: [Error] = [
            urlError,
            NSError(domain: "fixture", code: 7, userInfo: [NSUnderlyingErrorKey: urlError]),
            NSError(domain: NSURLErrorDomain, code: URLError.cannotConnectToHost.rawValue, userInfo: [
                NSURLErrorFailingURLStringErrorKey: keyed
            ]),
            TransferServiceError.transferFailed(reason: "node \(keyed) refused"),
            UniversalWalletHTTPTransportError.httpStatusCode(403, Data(keyed.utf8))
        ]
        for error in errors {
            let text = error.logSafeDescription
            XCTAssertFalse(text.contains("secret-key-123"), text)
            XCTAssertFalse(text.contains("example-provider.com/v2"), text)
        }
        XCTAssertEqual(urlError.logSafeDescription, "URLError(\(URLError.timedOut.rawValue))")
        XCTAssertEqual(SolanaRpcClientError.httpStatusCode(429).logSafeDescription, "httpStatusCode(429)")
        XCTAssertEqual(LogRedaction.redactingURLs(in: "failed at \(keyed), retrying"), "failed at <url> retrying")
    }

    func testUserSelectedNodeIsAskedFirst() throws {
        let selected = try ChainNodeModel(url: XCTUnwrap(URL(string: Self.publicNode)), name: "publicnode", apikey: nil)
        let mainnet = UniversalWalletRegistry.solanaMainnetChainModel.replacingSelectedNode(selected)

        XCTAssertEqual(
            SolanaRpcEndpoints.endpoints(for: mainnet, network: UniversalWalletRegistry.solanaMainnet, providerURL: nil),
            [Self.publicNode, Self.mainnetBeta, Self.vibeStation]
        )
    }

    func testExpiryRPCRejectsNonBooleanValidityAndMalformedContext() async throws {
        for value in ["0", "1", "null", "\"false\""] {
            let rpc = try SolanaRpcClient(transport: FakeSolanaRpcTransport(fixedResponse:
                Self.rpcResponse(id: 1, result: "{\"context\":{\"slot\":100},\"value\":\(value)}")))
            await assertRpcError(.invalidBlockhashResponse) {
                _ = try await rpc.blockhashValidity(Self.blockhash, minContextSlot: 1, rpcURL: nil)
            }
        }
        for slot in ["true", "false", "-1", "1.5", "18446744073709551615", "null", "\"100\""] {
            let rpc = try SolanaRpcClient(transport: FakeSolanaRpcTransport(fixedResponse:
                Self.rpcResponse(id: 1, result: "{\"context\":{\"slot\":\(slot)},\"value\":false}")))
            await assertRpcError(.invalidBlockhashResponse) {
                _ = try await rpc.blockhashValidity(Self.blockhash, minContextSlot: 1, rpcURL: nil)
            }
        }
    }

    func testExpiryRPCRejectsMalformedStatusContextAndBlockHash() async throws {
        for slot in ["true", "1.5", "-1", "null"] {
            let rpc = try SolanaRpcClient(transport: FakeSolanaRpcTransport(fixedResponse:
                Self.rpcResponse(id: 1, result: "{\"context\":{\"slot\":\(slot)},\"value\":[null]}")))
            await assertRpcError(.invalidSignatureStatusResponse) {
                _ = try await rpc.signatureStatusObservation(Self.signature, rpcURL: nil)
            }
        }
        let rpc = try SolanaRpcClient(transport: FakeSolanaRpcTransport(fixedResponse:
            Self.rpcResponse(id: 1, result: #"{"blockhash":"bad"}"#)))
        do { _ = try await rpc.finalizedBlockhash(slot: 1, rpcURL: nil); XCTFail("Invalid hash") }
        catch { XCTAssertEqual(error as? SolanaRpcClientError, .invalidAccountAddress) }
    }

    private func assertFailoverError(
        _ expected: SolanaRpcClientError?,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected an error", file: file, line: line)
        } catch {
            if let expected {
                XCTAssertEqual(error as? SolanaRpcClientError, expected, file: file, line: line)
            }
        }
    }

    /// Answers getBlockHeight with the request's own id, from any thread.
    private final class EchoingHeightTransport: UniversalWalletHTTPTransport {
        private let lock = NSLock()
        private var seenIds: [Int] = []

        var ids: [Int] {
            lock.lock()
            defer { lock.unlock() }
            return seenIds
        }

        func perform(_ request: URLRequest) async throws -> Data {
            let body = try XCTUnwrap(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
            let id = try XCTUnwrap(body["id"] as? Int)
            record(id)
            if body["method"] as? String == "getGenesisHash" {
                return SolanaRpcClientTests.rpcResponse(id: id, result: "\"\(UniversalWalletRegistry.solanaDevnet.genesisHash)\"")
            }
            return SolanaRpcClientTests.rpcResponse(id: id, result: "\(id)")
        }

        private func record(_ id: Int) {
            lock.lock()
            seenIds.append(id)
            lock.unlock()
        }
    }

    /// Answers each JSON-RPC request by node URL and method, echoing the request id.
    private final class RoutedSolanaTransport: UniversalWalletHTTPTransport {
        enum Answer {
            case success(String, error: String? = nil)
            case failure(Error)
        }

        private let route: (String, String, Int) -> Answer
        private(set) var urls: [String] = []
        private(set) var bodies: [[String: Any]] = []

        init(route: @escaping (_ url: String, _ method: String, _ id: Int) -> Answer) {
            self.route = route
        }

        func perform(_ request: URLRequest) async throws -> Data {
            let url = request.url?.absoluteString ?? ""
            let body = try (request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] }) ?? [:]
            let id = body["id"] as? Int ?? 0
            // Keep prior payload/failover assertions indexed by business RPC. Cluster adversarial
            // tests use ClusterTransport and record the complete unfiltered handshake sequence.
            if body["method"] as? String == "getGenesisHash" {
                let hash = url == SolanaRpcClientTests.devnetRPC
                    ? UniversalWalletRegistry.solanaDevnet.genesisHash : UniversalWalletRegistry.solanaMainnet.genesisHash
                return SolanaRpcClientTests.rpcResponse(id: id, result: "\"\(hash)\"")
            }
            urls.append(url)
            bodies.append(body)

            switch route(url, body["method"] as? String ?? "", id) {
            case let .success(result, error):
                if let error {
                    return Data(#"{"jsonrpc":"2.0","id":\#(id),"error":\#(error)}"#.utf8)
                }
                return SolanaRpcClientTests.rpcResponse(id: id, result: result)
            case let .failure(error):
                throw error
            }
        }
    }

    private static let provider = "https://solana-mainnet.example-provider.com/v2/key123"
    private static let mainnetBeta = "https://api.mainnet-beta.solana.com"
    private static let publicNode = "https://solana-rpc.publicnode.com"
    private static let vibeStation = "https://public.rpc.solanavibestation.com"
    private static let owner = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let tokenAccountsResult = #"""
    {"context":{"slot":5},"value":[
      {"pubkey":"3Mc6vR8ZuxJ7S6oRAQJ8rvxk8nBBWqfnXWDE6QvzgSkd","account":{"owner":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA","lamports":2039280,"executable":false,
        "data":{"program":"spl-token","space":165,"parsed":{"type":"account","info":{"mint":"EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v","owner":"HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk","state":"initialized","isNative":false,
          "tokenAmount":{"amount":"1250000","decimals":6,"uiAmountString":"1.25"}}}}}},
      {"pubkey":"not a key","account":{}},
      {"pubkey":"5N3f1tj9v1vc5TUZ8S7mCAnVmjVKrfnzXWhxLaxyZAgt","account":{"owner":"TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb","lamports":2039280,"executable":false,
        "data":{"program":"spl-token-2022","space":165,"parsed":{"type":"account","info":{"mint":"EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v","owner":"HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk",
          "tokenAmount":{"amount":"1","decimals":6}}}}}}
    ]}
    """#

    private final class FakeSolanaRpcTransport: UniversalWalletHTTPTransport {
        private let fixedResponse: Data?
        private(set) var requests: [URLRequest] = []
        private(set) var requestBodies: [[String: Any]] = []

        init(fixedResponse: Data? = nil) {
            self.fixedResponse = fixedResponse
        }

        func perform(_ request: URLRequest) async throws -> Data {
            let body = try XCTUnwrap(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
            let id = body["id"] as? Int ?? 0
            if body["method"] as? String == "getGenesisHash" {
                let hash = request.url?.absoluteString == SolanaRpcClientTests.devnetRPC
                    ? UniversalWalletRegistry.solanaDevnet.genesisHash : UniversalWalletRegistry.solanaMainnet.genesisHash
                return SolanaRpcClientTests.rpcResponse(id: id, result: "\"\(hash)\"")
            }
            requests.append(request)
            requestBodies.append(body)
            if let fixedResponse {
                // Fixtures historically used request id 1. Preserve intentional ID mismatch
                // relative to the actual payload id, after the new independent handshake.
                var response = try XCTUnwrap(JSONSerialization.jsonObject(with: fixedResponse) as? [String: Any])
                if let fixtureId = response["id"] as? Int { response["id"] = id + fixtureId - 1 }
                return try JSONSerialization.data(withJSONObject: response)
            }

            switch body["method"] as? String {
            case "getLatestBlockhash":
                return SolanaRpcClientTests.rpcResponse(
                    id: id,
                    result: #"{"context":{"apiVersion":"2.0.0","slot":123},"value":{"blockhash":"\#(SolanaRpcClientTests.blockhash)","lastValidBlockHeight":456}}"#
                )
            case "getFeeForMessage":
                return SolanaRpcClientTests.rpcResponse(id: id, result: #"{"context":{"slot":124},"value":5000}"#)
            case "getMinimumBalanceForRentExemption":
                return SolanaRpcClientTests.rpcResponse(id: id, result: "890880")
            case "getAccountInfo":
                return SolanaRpcClientTests.rpcResponse(
                    id: id,
                    result: #"{"context":{"slot":124},"value":{"lamports":2039280,"owner":"TokenzQdBNbLqP5VEkvhsuKq2G6Z1Lx8pGMyrEKHKzJ"}}"#
                )
            case "simulateTransaction":
                return SolanaRpcClientTests.rpcResponse(
                    id: id,
                    result: #"{"context":{"slot":124},"value":{"err":null,"logs":["Program log: ok"],"replacementBlockhash":{"blockhash":"\#(SolanaRpcClientTests.blockhash)","lastValidBlockHeight":789},"unitsConsumed":321}}"#
                )
            case "sendTransaction":
                return SolanaRpcClientTests.rpcResponse(id: id, result: #""\#(SolanaRpcClientTests.signature)""#)
            default:
                return SolanaRpcClientTests.data(#"{"jsonrpc":"2.0","id":\#(id),"result":null}"#)
            }
        }
    }

    private func assertRpcError(
        _ expected: SolanaRpcClientError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected Solana RPC error", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? SolanaRpcClientError, expected, file: file, line: line)
        }
    }

    private static let devnetRPC = "https://api.devnet.solana.com"
    private static let transaction = "AQIDBA=="
    private static let accountAddress = "So11111111111111111111111111111111111111112"
    private static let blockhash = "7GjNiPun3AzEazTZoFEjZgcBMeuaXdpjHq2raZTmTrfs"
    private static let signature = "5NfHnqDyzT9qyfxZDq2sSskAMGuFZ3VRqW4EQxghKqrKYdKq6cZNW1J34w7qE6nGx1eDQe5s2eKxB2ZtE1xU9qgN"

    private static func rpcResponse(id: Int, result: String) -> Data {
        data(#"{"jsonrpc":"2.0","id":\#(id),"result":\#(result)}"#)
    }

    private static func data(_ value: String) -> Data {
        Data(value.utf8)
    }
}

/// Serves Solana JSON-RPC over a URLSession without any network, routed per node and method,
/// and records each request with the time `now` gives.
private final class SolanaNodeURLProtocol: URLProtocol {
    typealias Route = (_ url: String, _ method: String, _ programId: String?, _ id: Int) -> (Int, [String: String], Data)

    struct Request {
        let url: String
        let method: String
        let at: TimeInterval
    }

    private static let lock = NSLock()
    private static var route: Route?
    private static var now: () -> TimeInterval = { 0 }
    private static var recorded: [Request] = []

    static func install(now: @escaping () -> TimeInterval, route: @escaping Route) {
        lock.lock()
        defer { lock.unlock() }
        self.route = route
        self.now = now
        recorded = []
    }

    static func uninstall() {
        lock.lock()
        defer { lock.unlock() }
        route = nil
        recorded = []
    }

    static var requests: [Request] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let bodyData = request.httpBody ?? Self.readAll(request.httpBodyStream)
        let body = bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let url = request.url?.absoluteString ?? ""
        let method = body["method"] as? String ?? ""
        let id = body["id"] as? Int ?? 0
        let programId = ((body["params"] as? [Any])?.dropFirst().first as? [String: Any])?["programId"] as? String

        Self.lock.lock()
        let route = Self.route
        Self.recorded.append(Request(url: url, method: method, at: Self.now()))
        Self.lock.unlock()

        let answer: (Int, [String: String], Data)
        if method == "getGenesisHash" {
            answer = (200, ["Content-Type": "application/json"],
                      Data(#"{"jsonrpc":"2.0","id":\#(id),"result":"\#(UniversalWalletRegistry.solanaMainnet.genesisHash)"}"#.utf8))
        } else {
            answer = route?(url, method, programId, id) ?? (500, [:], Data())
        }
        guard let requestURL = request.url,
              let response = HTTPURLResponse(url: requestURL, statusCode: answer.0, httpVersion: "HTTP/1.1", headerFields: answer.1) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.2)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream?) -> Data? {
        guard let stream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}

