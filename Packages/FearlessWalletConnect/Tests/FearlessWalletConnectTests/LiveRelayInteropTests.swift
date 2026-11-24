import XCTest
@testable import FearlessWalletConnect

/// The wallet on the live WalletConnect relay against a dApp running the WalletConnect SDK most dApps ship
/// (`scripts/walletconnect/reference-dapp.mjs`, with the SDK installed outside this repository). Skipped unless
/// `FEARLESS_WC_LIVE=1`; see docs/walletconnect-protocol.md for how to run both sides.
final class LiveRelayInteropTests: XCTestCase {
    private struct Environment {
        let projectId: String
        let exchange: URL
        let relayURL: URL
    }

    private func environment() throws -> Environment {
        let values = ProcessInfo.processInfo.environment
        guard
            values["FEARLESS_WC_LIVE"] == "1",
            let projectId = values["WALLETCONNECT_PROJECT_ID"], !projectId.isEmpty,
            let exchange = values["FEARLESS_WC_EXCHANGE"]
        else {
            throw XCTSkip("Live relay interop runs only with FEARLESS_WC_LIVE=1")
        }
        return Environment(
            projectId: projectId,
            exchange: URL(fileURLWithPath: exchange),
            relayURL: URL(string: values["WALLETCONNECT_RELAY_URL"] ?? "wss://relay.walletconnect.com")!
        )
    }

    private func waitForFile(_ name: String, in directory: URL, timeout: TimeInterval = 180) async throws -> String {
        let url = directory.appendingPathComponent(name)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                return text
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw TestFailure("no \(name) from the dApp")
    }

    func testTheWalletSettlesAnswersRefusesAndEndsSessionsWithTheReferenceSDK() async throws {
        let environment = try environment()
        var log: [[String: String]] = []
        func note(_ step: String, _ detail: String = "") {
            log.append(["step": step, "detail": detail, "at": ISO8601DateFormatter().string(from: Date())])
            print("[wallet] \(step) \(detail)")
        }

        let store = InMemoryWalletConnectStore()
        let wallet = WalletConnectClient(
            configuration: .init(
                projectId: environment.projectId,
                relayURL: environment.relayURL,
                metadata: fearlessMetadata,
                bundleId: ProcessInfo.processInfo.environment["WALLETCONNECT_BUNDLE_ID"],
                userAgent: "wc-2/fearless-wallet-ios/interop"
            ),
            stateStore: store,
            secretStore: store,
            verify: VerifyClient()
        )
        let events = EventRecorder(wallet)
        try await wallet.start()
        note("client ready", try await wallet.clientId())

        // 1. Approval.
        let link = try await waitForFile("uri-approve.txt", in: environment.exchange)
        try await wallet.pair(uri: WalletConnectURI(uriString: link))
        let proposal = try await events.waitForProposal(timeout: 60)
        let context = try XCTUnwrap(events.proposals().last?.1)
        note("proposal received", "\(proposal.proposer.name), verify \(context.validation.rawValue) \(context.origin)")

        let polkadot = Blockchain("polkadot:91b171bb158e2d3848fa23a9f1c25182")!
        let namespaces = try AutoNamespaces.build(
            sessionProposal: proposal,
            chains: [ethereum, polkadot],
            methods: ["personal_sign", "eth_signTypedData_v4", "polkadot_signMessage", "polkadot_signTransaction"],
            events: ["chainChanged", "accountsChanged"],
            accounts: [
                Account(blockchain: ethereum, address: evmAddress)!,
                Account(blockchain: polkadot, address: "15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5")!
            ]
        )
        let session = try await wallet.approve(proposalId: proposal.id, namespaces: namespaces)
        try await waitUntil(timeout: 60) { await wallet.isAcknowledged(topic: session.topic) }
        note("session acknowledged", String(session.topic.prefix(8)))

        // 2. A request answered and a request refused.
        let sign = try await events.waitForRequest(count: 1, timeout: 120)
        XCTAssertEqual(sign.method, "personal_sign")
        XCTAssertEqual(sign.chainId, ethereum)
        XCTAssertEqual(try sign.params.get([String].self), ["0x48656c6c6f", evmAddress])
        try await wallet.respond(topic: session.topic, requestId: sign.id, response: .response(AnyCodable("0xfearless-interop-signature")))
        note("personal_sign answered")

        let refused = try await events.waitForRequest(count: 2, timeout: 120)
        XCTAssertEqual(refused.method, "polkadot_signMessage")
        XCTAssertEqual(refused.chainId, polkadot)
        try await wallet.respond(
            topic: session.topic,
            requestId: refused.id,
            response: .error(JSONRPCError(code: 4001, message: "User rejected request"))
        )
        note("polkadot_signMessage refused")

        // 3. Ping both ways, then the wallet ends the session.
        try await wallet.ping(topic: session.topic)
        note("dApp answered the wallet's ping")
        _ = try await waitForFile("dapp-ready-for-delete.txt", in: environment.exchange)
        XCTAssertTrue(events.contains {
            if case let .sessionPinged(topic) = $0 {
                return topic == session.topic
            }
            return false
        })
        try await wallet.disconnect(topic: session.topic)
        note("session ended by the wallet")

        // 4. Refusal of a second proposal.
        let refusalLink = try await waitForFile("uri-reject.txt", in: environment.exchange)
        try await wallet.pair(uri: WalletConnectURI(uriString: refusalLink))
        let second = try await events.waitFor(timeout: 60) {
            events.proposals().map(\.0).first { $0.id != proposal.id }
        }
        try await wallet.reject(proposalId: second.id, reason: .userRejected)
        note("second proposal refused")

        let result = try await waitForFile("result.json", in: environment.exchange, timeout: 120)
        let parsed = try JSONParser.parse(result)
        note("dApp result", "ok=\(parsed["ok"]?.boolValue == true) sdk=\(parsed["sdk"]?.stringValue ?? "?")")
        XCTAssertEqual(parsed["ok"]?.boolValue, true, result)

        let walletLog = JSONValue.array(log.map { entry in .object(entry.mapValues(JSONValue.string)) })
        try JSONSerializer.data(from: .object([
            "client": .string("FearlessWalletConnect (in-repo)"),
            "relayUrl": .string(environment.relayURL.absoluteString),
            "steps": walletLog
        ])).write(to: environment.exchange.appendingPathComponent("wallet.json"))
        await wallet.stop()
    }
}
