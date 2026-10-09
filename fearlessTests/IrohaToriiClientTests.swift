import XCTest
@testable import fearless

final class IrohaToriiClientTests: XCTestCase {
    func testIrohaRedirectDelegateRefusesCrossOriginRedirect() throws {
        let delegate = IrohaNoRedirectURLSessionDelegate()
        let session = URLSession(configuration: .ephemeral)
        let originalURL = try XCTUnwrap(URL(string: "https://taira.sora.org/v1/mcp"))
        let attackerURL = try XCTUnwrap(URL(string: "https://attacker.invalid/final"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: originalURL,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": attackerURL.absoluteString]
            )
        )
        let task = session.dataTask(with: originalURL)
        let completion = expectation(description: "redirect decision")

        delegate.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: attackerURL)
        ) { redirectedRequest in
            XCTAssertNil(redirectedRequest)
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        task.cancel()
        session.invalidateAndCancel()
    }

    func testDelegatesReadEndpointsThroughValidatedToriiRoutes() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Self.accountListJSON)
        _ = try await client.accounts(limit: 50, offset: 10, countMode: .exact)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://taira.sora.org/v1/accounts?limit=50&offset=10&count_mode=exact"
        )
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")

        transport.enqueue(Self.accountAssetsJSON)
        _ = try await client.accountAssets(
            accountID: Self.account,
            limit: 25,
            countMode: .bounded,
            asset: Self.assetDefinitionId,
            scope: "global"
        )
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/assets?limit=25&count_mode=bounded&asset=\(Self.assetDefinitionId)&scope=global"
        )

        transport.enqueue(Self.transactionStatusJSON)
        _ = try await client.transactionStatus(hash: Self.hash, scope: .global)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://taira.sora.org/v1/pipeline/transactions/status?hash=\(Self.hash)&scope=global"
        )
    }

    func testSubmitsAndWaitsThroughCanonicalMCPToolWithExplicitHashAndAppliedTerminal() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Self.submitAndWaitJSON())
        let outcome = try await client.submitTransactionAndWait(
            noritoBytes: Data([1, 2, 3]),
            expectedHash: Self.hash,
            timeoutMilliseconds: 12_000,
            pollIntervalMilliseconds: 500,
            network: UniversalWalletRegistry.taira,
            baseURL: nil
        )
        XCTAssertEqual(outcome.terminalKind, .applied)
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://taira.sora.org/v1/mcp")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        let request = try JSONDecoder().decode(
            IrohaMcpJsonRPCRequest.self,
            from: XCTUnwrap(transport.lastRequest?.httpBody)
        )
        XCTAssertEqual(request.method, "tools/call")
        XCTAssertEqual(request.params?["name"], .string("iroha.transactions.submit_and_wait"))
        guard case let .object(arguments)? = request.params?["arguments"] else {
            return XCTFail("Missing submit-and-wait arguments")
        }
        XCTAssertEqual(arguments["body_base64"], .string("AQID"))
        XCTAssertEqual(arguments["hash"], .string(Self.hash))
        XCTAssertEqual(arguments["terminal_statuses"], .array([.string("Applied")]))
        XCTAssertEqual(arguments["timeout_ms"], .int(12_000))
        XCTAssertEqual(arguments["poll_interval_ms"], .int(500))
    }

    func testDelegatesGenericMCPWithExplicitTransportContract() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Self.mcpResponseJSON)
        _ = try await client.mcpJSONRPC(
            try IrohaToriiRoutes.mcpJSONRPCRequest(method: "tools/list", id: "1")
        )
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://taira.sora.org/v1/mcp")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNotNil(transport.lastRequest?.httpBody)
    }

    func testRejectsJSONRPCResponsesThatAreNotExactlyBoundToTheRequest() async throws {
        let responses = [
            #"{"id":"1","result":{}}"#,
            #"{"jsonrpc":"1.0","id":"1","result":{}}"#,
            #"{"jsonrpc":"2.0","id":"wrong-id","result":{}}"#,
            #"{"jsonrpc":"2.0","id":"1"}"#,
            #"{"jsonrpc":"2.0","id":"1","result":{},"error":{"code":-32603,"message":"ambiguous"}}"#
        ]

        for json in responses {
            let transport = FakeIrohaToriiTransport()
            transport.enqueue(Data(json.utf8))
            do {
                _ = try await IrohaToriiClient(transport: transport).mcpJSONRPC(
                    try IrohaToriiRoutes.mcpJSONRPCRequest(method: "tools/list", id: "1")
                )
                XCTFail("Expected unbound JSON-RPC response to fail")
            } catch {
                XCTAssertEqual(error as? IrohaToriiReadError, .invalidJSONRPCResponse)
            }
        }
    }

    func testAcceptsMCPTransportWithoutOuterFanoutWhenNestedRoutesAreComplete() async throws {
        let transport = FakeIrohaToriiTransport()
        transport.responseHeaders = ["Content-Type": "application/json; charset=utf-8"]
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Self.submitAndWaitJSON())
        let outcome = try await client.submitTransactionAndWait(
            noritoBytes: Data([1, 2, 3]),
            expectedHash: Self.hash,
            timeoutMilliseconds: 12_000,
            pollIntervalMilliseconds: 500,
            network: UniversalWalletRegistry.taira,
            baseURL: nil
        )
        XCTAssertEqual(outcome.terminalKind, .applied)

        transport.enqueue(Data("{}".utf8))
        let capabilities = try await client.mcpCapabilities()
        XCTAssertEqual(capabilities, Data("{}".utf8))
    }

    func testRejectsNonJSONAndCaseCollidingOuterSuccessfulResponses() async throws {
        let nonJSONTransport = FakeIrohaToriiTransport()
        nonJSONTransport.responseHeaders["Content-Type"] = "text/plain"
        nonJSONTransport.enqueue(Self.accountListJSON)
        let nonJSONClient = IrohaToriiClient(transport: nonJSONTransport)

        do {
            _ = try await nonJSONClient.accounts()
            XCTFail("Expected non-JSON routed response to fail")
        } catch {
            XCTAssertEqual(error as? IrohaToriiReadError, .invalidJSONContentType)
        }

        nonJSONTransport.enqueue(Data("{}".utf8))
        do {
            _ = try await nonJSONClient.mcpCapabilities()
            XCTFail("Expected non-JSON MCP response to fail")
        } catch {
            XCTAssertEqual(error as? IrohaToriiReadError, .invalidJSONContentType)
        }

        let duplicateTransport = FakeIrohaToriiTransport()
        duplicateTransport.responseHeaders["content-type"] = "application/json"
        duplicateTransport.enqueue(Self.accountListJSON)
        do {
            _ = try await IrohaToriiClient(transport: duplicateTransport).accounts()
            XCTFail("Expected case-colliding response headers to fail")
        } catch {
            XCTAssertEqual(error as? IrohaToriiReadError, .malformedResponseHeaders)
        }
    }

    func testRejectsNonJSONAndCaseCollidingNestedRouteMetadata() async throws {
        let nonJSONTransport = FakeIrohaToriiTransport()
        nonJSONTransport.enqueue(Self.submitAndWaitJSON(submitContentType: "text/plain"))
        do {
            _ = try await IrohaToriiClient(transport: nonJSONTransport).submitTransactionAndWait(
                noritoBytes: Data([1]),
                expectedHash: Self.hash,
                timeoutMilliseconds: 1_000,
                pollIntervalMilliseconds: 100,
                network: UniversalWalletRegistry.taira,
                baseURL: nil
            )
            XCTFail("Expected non-JSON nested route to fail")
        } catch {
            XCTAssertEqual(error as? IrohaSubmitAndWaitError, .invalidResponse)
        }

        var collidingHeaders = Self.completeFanoutHeaders
        collidingHeaders["X-Iroha-Fanout-Routes-Attempted"] = "1"
        let collisionTransport = FakeIrohaToriiTransport()
        collisionTransport.enqueue(Self.submitAndWaitJSON(submitHeaders: collidingHeaders))
        do {
            _ = try await IrohaToriiClient(transport: collisionTransport).submitTransactionAndWait(
                noritoBytes: Data([1]),
                expectedHash: Self.hash,
                timeoutMilliseconds: 1_000,
                pollIntervalMilliseconds: 100,
                network: UniversalWalletRegistry.taira,
                baseURL: nil
            )
            XCTFail("Expected case-colliding nested headers to fail")
        } catch {
            XCTAssertEqual(error as? IrohaToriiReadError, .malformedFanoutHeaders)
        }
    }

    func testRejectsDegradedNestedSubmitAndWaitFanout() async throws {
        let transport = FakeIrohaToriiTransport()
        transport.enqueue(
            Self.submitAndWaitJSON(
                submitHeaders: [
                    "x-iroha-fanout-routes-attempted": "2",
                    "x-iroha-fanout-routes-succeeded": "1",
                    "x-iroha-fanout-routes-failed": "1",
                    "x-iroha-fanout-routes-denied": "1",
                    "x-iroha-fanout-routes-unavailable": "0",
                    "x-iroha-fanout-routes-not-found": "0"
                ]
            )
        )
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.submitTransactionAndWait(
                noritoBytes: Data([1]),
                expectedHash: Self.hash,
                timeoutMilliseconds: 1_000,
                pollIntervalMilliseconds: 100,
                network: UniversalWalletRegistry.taira,
                baseURL: nil
            )
            XCTFail("Expected nested degraded fanout to fail")
        } catch let IrohaToriiReadError.degraded(fanout) {
            XCTAssertEqual(fanout.denied, 1)
            XCTAssertFalse(fanout.isComplete)
        }
    }

    func testClassifiesSubmitAndWaitRejectedExpiredAndTimeoutToolErrors() async throws {
        let cases: [(String, IrohaSubmitAndWaitError)] = [
            ("last_status=Rejected: policy denied", .rejected("last_status=Rejected: policy denied")),
            ("last_status=Expired", .expired("last_status=Expired")),
            (
                "timed out waiting for terminal transaction status",
                .timeout("timed out waiting for terminal transaction status")
            )
        ]

        for (message, expectedError) in cases {
            let transport = FakeIrohaToriiTransport()
            transport.enqueue(Self.submitAndWaitToolErrorJSON(message: message))
            let client = IrohaToriiClient(transport: transport)
            do {
                _ = try await client.submitTransactionAndWait(
                    noritoBytes: Data([1]),
                    expectedHash: Self.hash,
                    timeoutMilliseconds: 1_000,
                    pollIntervalMilliseconds: 100,
                    network: UniversalWalletRegistry.taira,
                    baseURL: nil
                )
                XCTFail("Expected typed submit-and-wait failure")
            } catch let error as IrohaSubmitAndWaitError {
                XCTAssertEqual(error, expectedError)
            }
        }
    }

    func testRejectsEvenMarkerExpectedHashBeforeMCPSubmission() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.submitTransactionAndWait(
                noritoBytes: Data([1]),
                expectedHash: String(repeating: "a", count: 64),
                timeoutMilliseconds: 1_000,
                pollIntervalMilliseconds: 100,
                network: UniversalWalletRegistry.taira,
                baseURL: nil
            )
            XCTFail("Expected even-marker hash to fail")
        } catch {
            XCTAssertEqual(error as? IrohaSubmitAndWaitError, .invalidResponse)
            XCTAssertNil(transport.lastRequest)
        }
    }

    func testRejectsNonCanonicalTransactionHashSpellingsWithoutNormalization() async throws {
        for nonCanonicalHash in ["0x\(Self.hash)", Self.hash.uppercased(), " \(Self.hash)"] {
            let transport = FakeIrohaToriiTransport()
            do {
                _ = try await IrohaToriiClient(transport: transport).submitTransactionAndWait(
                    noritoBytes: Data([1]),
                    expectedHash: nonCanonicalHash,
                    timeoutMilliseconds: 1_000,
                    pollIntervalMilliseconds: 100,
                    network: UniversalWalletRegistry.taira,
                    baseURL: nil
                )
                XCTFail("Expected non-canonical local hash to fail")
            } catch {
                XCTAssertEqual(error as? IrohaSubmitAndWaitError, .invalidResponse)
                XCTAssertNil(transport.lastRequest)
            }
        }

        let responses = [
            Self.submitAndWaitJSON(outcomeHash: "0x\(Self.hash)"),
            Self.submitAndWaitJSON(transactionHash: Self.hash.uppercased()),
            Self.submitAndWaitJSON(receiptHash: " \(Self.hash)"),
            Self.submitAndWaitJSON(finalHash: "\(Self.hash)\n")
        ]
        for response in responses {
            let transport = FakeIrohaToriiTransport()
            transport.enqueue(response)
            do {
                _ = try await IrohaToriiClient(transport: transport).submitTransactionAndWait(
                    noritoBytes: Data([1]),
                    expectedHash: Self.hash,
                    timeoutMilliseconds: 1_000,
                    pollIntervalMilliseconds: 100,
                    network: UniversalWalletRegistry.taira,
                    baseURL: nil
                )
                XCTFail("Expected non-canonical remote hash to fail")
            } catch {
                XCTAssertEqual(error as? IrohaSubmitAndWaitError, .invalidResponse)
            }
        }
    }

    func testRejectsAnySubmitAndWaitHashThatDiffersFromLocalExpectedHash() async throws {
        let mismatch = String(repeating: "c", count: 63) + "3"
        let responses = [
            Self.submitAndWaitJSON(outcomeHash: mismatch),
            Self.submitAndWaitJSON(transactionHash: mismatch),
            Self.submitAndWaitJSON(receiptHash: mismatch),
            Self.submitAndWaitJSON(finalHash: mismatch)
        ]

        for response in responses {
            let transport = FakeIrohaToriiTransport()
            transport.enqueue(response)
            let client = IrohaToriiClient(transport: transport)
            do {
                _ = try await client.submitTransactionAndWait(
                    noritoBytes: Data([1]),
                    expectedHash: Self.hash,
                    timeoutMilliseconds: 1_000,
                    pollIntervalMilliseconds: 100,
                    network: UniversalWalletRegistry.taira,
                    baseURL: nil
                )
                XCTFail("Expected mismatched submit-and-wait hash to fail")
            } catch {
                XCTAssertEqual(error as? IrohaSubmitAndWaitError, .invalidResponse)
            }
        }
    }

    func testRejectsMatchingButNonAppliedSubmitAndWaitFinality() async throws {
        let transport = FakeIrohaToriiTransport()
        transport.enqueue(Self.submitAndWaitJSON(terminalKind: "Committed"))
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.submitTransactionAndWait(
                noritoBytes: Data([1]),
                expectedHash: Self.hash,
                timeoutMilliseconds: 1_000,
                pollIntervalMilliseconds: 100,
                network: UniversalWalletRegistry.taira,
                baseURL: nil
            )
            XCTFail("Expected non-Applied finality to fail")
        } catch {
            XCTAssertEqual(error as? IrohaSubmitAndWaitError, .invalidResponse)
        }
    }

    func testUsesMinamotoForNexusByDefaultAndAllowsRuntimeOverride() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Data("{}".utf8))
        _ = try await client.mcpCapabilities(network: UniversalWalletRegistry.nexus)
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://minamoto.sora.org/v1/mcp")

        transport.enqueue(Data("{}".utf8))
        _ = try await client.mcpCapabilities(
            network: UniversalWalletRegistry.nexus,
            baseURL: "https://nexus.example"
        )
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://nexus.example/v1/mcp")
    }

    func testRejectsWrongNetworkIrohaAccountIDsBeforeFetch() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.account(accountID: Self.nexusAccount)
            XCTFail("Expected Nexus account to be rejected for default Taira reads")
        } catch {
            XCTAssertEqual(error as? IrohaAddressError, IrohaAddressError(code: .unexpectedNetworkPrefix))
            XCTAssertNil(transport.lastRequest)
        }

        transport.enqueue(Self.accountListItemJSON(account: Self.nexusAccount))
        _ = try await client.account(
            accountID: Self.nexusAccount,
            baseURL: "https://nexus.example",
            network: UniversalWalletRegistry.nexus
        )
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://nexus.example/v1/accounts/\(Self.encodedNexusAccount)"
        )
    }

    func testRejectsPartialSuccessfulFanoutResponse() async throws {
        let transport = FakeIrohaToriiTransport()
        transport.responseHeaders = [
            "x-iroha-fanout-routes-attempted": "5",
            "x-iroha-fanout-routes-succeeded": "1",
            "x-iroha-fanout-routes-failed": "4",
            "x-iroha-fanout-routes-denied": "1",
            "x-iroha-fanout-routes-unavailable": "2",
            "x-iroha-fanout-routes-not-found": "1"
        ]
        transport.enqueue(Self.accountListJSON)
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.accounts()
            XCTFail("Expected partial fanout response to fail")
        } catch let IrohaToriiReadError.degraded(fanout) {
            XCTAssertEqual(fanout.attempted, 5)
            XCTAssertEqual(fanout.succeeded, 1)
            XCTAssertEqual(fanout.denied, 1)
            XCTAssertEqual(fanout.notFound, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsIncompleteSixHeaderFanoutContract() async throws {
        let transport = FakeIrohaToriiTransport()
        transport.responseHeaders = [
            "x-iroha-fanout-routes-attempted": "1",
            "x-iroha-fanout-routes-succeeded": "1",
            "x-iroha-fanout-routes-failed": "0",
            "x-iroha-fanout-routes-denied": "0",
            "x-iroha-fanout-routes-unavailable": "0"
        ]
        transport.enqueue(Self.accountListJSON)
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.accounts()
            XCTFail("Expected incomplete fanout metadata to fail")
        } catch {
            XCTAssertEqual(error as? IrohaToriiReadError, .malformedFanoutHeaders)
        }
    }

    func testRejectsSuccessfulRoutedReadsWithoutFanoutEvidence() async throws {
        let transport = FakeIrohaToriiTransport()
        transport.responseHeaders = [:]
        transport.enqueue(Self.accountListJSON)
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.accounts()
            XCTFail("Expected missing fanout metadata to fail")
        } catch {
            XCTAssertEqual(error as? IrohaToriiReadError, .malformedFanoutHeaders)
        }
    }

    func testRejectsOverflowingFanoutCountersWithoutTrapping() async throws {
        let transport = FakeIrohaToriiTransport()
        let maximum = String(Int.max)
        transport.responseHeaders = [
            "x-iroha-fanout-routes-attempted": maximum,
            "x-iroha-fanout-routes-succeeded": "0",
            "x-iroha-fanout-routes-failed": maximum,
            "x-iroha-fanout-routes-denied": maximum,
            "x-iroha-fanout-routes-unavailable": maximum,
            "x-iroha-fanout-routes-not-found": maximum
        ]
        transport.enqueue(Self.accountListJSON)
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.accounts()
            XCTFail("Expected overflowing fanout counters to fail")
        } catch {
            XCTAssertEqual(error as? IrohaToriiReadError, .malformedFanoutHeaders)
        }
    }

    private final class FakeIrohaToriiTransport: IrohaToriiHTTPTransport {
        private var queuedResponses: [Data] = []
        private(set) var lastRequest: URLRequest?
        var responseHeaders: [AnyHashable: Any] = [
            "Content-Type": "application/json; charset=utf-8",
            "x-iroha-fanout-routes-attempted": "1",
            "x-iroha-fanout-routes-succeeded": "1",
            "x-iroha-fanout-routes-failed": "0",
            "x-iroha-fanout-routes-denied": "0",
            "x-iroha-fanout-routes-unavailable": "0",
            "x-iroha-fanout-routes-not-found": "0"
        ]

        func enqueue(_ data: Data) {
            queuedResponses.append(data)
        }

        func perform(_ request: URLRequest) async throws -> Data {
            lastRequest = request
            return queuedResponses.isEmpty ? Data("{}".utf8) : queuedResponses.removeFirst()
        }

        func performResponse(_ request: URLRequest) async throws -> UniversalWalletHTTPResponse {
            UniversalWalletHTTPResponse(data: try await perform(request), headers: responseHeaders)
        }
    }

    private static let account = "testuﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
    private static let encodedAccount = "testu%EF%BE%9B1Pc%EF%BE%852%EF%BE%97t%EF%BE%89a%EF%BE%98L%EF%BE%95%EF%BD%BD2M%E3%83%B1%EF%BE%90%EF%BE%8E%EF%BD%B3%EF%BE%93%E3%83%B1%EF%BD%B7%EF%BE%86%EF%BD%B2M%EF%BE%92S%EF%BE%8F%EF%BD%B1%E3%83%B1%EF%BD%B7J%E3%83%B1FmJ%EF%BE%87Ms6YN687Y"
    private static let nexusAccount = "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
    private static let encodedNexusAccount = "sorau%EF%BE%9B1Pc%EF%BE%852%EF%BE%97t%EF%BE%89a%EF%BE%98L%EF%BE%95%EF%BD%BD2M%E3%83%B1%EF%BE%90%EF%BE%8E%EF%BD%B3%EF%BE%93%E3%83%B1%EF%BD%B7%EF%BE%86%EF%BD%B2M%EF%BE%92S%EF%BE%8F%EF%BD%B1%E3%83%B1%EF%BD%B7J%E3%83%B1FmJ%EF%BE%87Ms6YN687Y"
    private static let hash = String(repeating: "a", count: 63) + "1"
    private static let assetDefinitionId = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"

    private static let accountListJSON = Data("""
    {
      "items": [{ "id": "\(account)" }],
      "has_more": false,
      "count_mode": "exact",
      "total": 1
    }
    """.utf8)

    private static func accountListItemJSON(account: String) -> Data {
        Data("""
        {
          "id": "\(account)"
        }
        """.utf8)
    }

    private static let accountAssetsJSON = Data("""
    {
      "items": [
        {
          "account_id": "\(account)",
          "asset": "\(assetDefinitionId)",
          "quantity": "340282366920938463463374607431768211455",
          "scope": "global"
        }
      ],
      "has_more": false,
      "count_mode": "bounded"
    }
    """.utf8)

    private static let transactionStatusJSON = Data("""
    {
      "hash": "\(hash)",
      "status": {
        "kind": "Committed",
        "block_height": 42
      },
      "scope": "global",
      "resolved_from": "state"
    }
    """.utf8)

    private static let completeFanoutHeaders = [
        "x-iroha-fanout-routes-attempted": "1",
        "x-iroha-fanout-routes-succeeded": "1",
        "x-iroha-fanout-routes-failed": "0",
        "x-iroha-fanout-routes-denied": "0",
        "x-iroha-fanout-routes-unavailable": "0",
        "x-iroha-fanout-routes-not-found": "0"
    ]

    private static func submitAndWaitJSON(
        submitHeaders: [String: String] = completeFanoutHeaders,
        finalHeaders: [String: String] = completeFanoutHeaders,
        submitContentType: String = "application/json; charset=utf-8",
        finalContentType: String = "application/json; charset=utf-8",
        outcomeHash: String? = nil,
        transactionHash: String? = nil,
        receiptHash: String? = nil,
        finalHash: String? = nil,
        terminalKind: String = "Applied"
    ) -> Data {
        let outcomeHash = outcomeHash ?? hash
        let transactionHash = transactionHash ?? hash
        let receiptHash = receiptHash ?? hash
        let finalHash = finalHash ?? hash
        let outcome: [String: Any] = [
            "status": 200,
            "hash": outcomeHash,
            "tx_hash": transactionHash,
            "terminal_kind": terminalKind,
            "terminal_statuses": ["Applied"],
            "attempts": 2,
            "elapsed_ms": 15,
            "submit": [
                "status": 202,
                "headers": submitHeaders,
                "content_type": submitContentType,
                "body": ["payload": ["entrypoint_hash": receiptHash]]
            ],
            "final_status": [
                "status": 200,
                "headers": finalHeaders,
                "content_type": finalContentType,
                "body": [
                    "hash": finalHash,
                    "status": ["kind": terminalKind, "block_height": 42],
                    "scope": "global",
                    "resolved_from": "state"
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": "submit-\(hash.prefix(16))",
            "result": [
                "content": [],
                "structuredContent": outcome,
                "isError": false
            ]
        ])
    }

    private static func submitAndWaitToolErrorJSON(message: String) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": "submit-\(hash.prefix(16))",
            "result": [
                "content": [],
                "structuredContent": ["message": message],
                "isError": true
            ]
        ])
    }

    private static let mcpResponseJSON = Data("""
    {
      "jsonrpc": "2.0",
      "id": "1",
      "result": {
        "ok": true
      }
    }
    """.utf8)
}
