import XCTest
@testable import fearless

final class SolanaRpcClientTests: XCTestCase {
    func testPostsValidatedJSONRPCRequestsToConfiguredSolanaRPCEndpoints() async throws {
        let transport = FakeSolanaRpcTransport()
        let client = try SolanaRpcClient(transport: transport, defaultRPCURL: Self.devnetRPC)

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

    private final class FakeSolanaRpcTransport: UniversalWalletHTTPTransport {
        private let fixedResponse: Data?
        private(set) var requests: [URLRequest] = []
        private(set) var requestBodies: [[String: Any]] = []

        init(fixedResponse: Data? = nil) {
            self.fixedResponse = fixedResponse
        }

        func perform(_ request: URLRequest) async throws -> Data {
            requests.append(request)
            if let body = request.httpBody,
               let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] {
                requestBodies.append(object)
            }
            if let fixedResponse {
                return fixedResponse
            }

            let body = requestBodies.last ?? [:]
            let id = body["id"] as? Int ?? 0
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
