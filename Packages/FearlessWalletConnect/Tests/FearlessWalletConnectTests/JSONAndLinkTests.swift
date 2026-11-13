import XCTest
@testable import FearlessWalletConnect

final class JSONTests: XCTestCase {
    func testNumbersKeepTheirExactText() throws {
        let text = #"{"big":123456789012345678901234567890,"small":-0.000000000000000000001,"int":9007199254740993}"#
        let value = try JSONParser.parse(text)

        XCTAssertEqual(value["big"]?.numberValue?.text, "123456789012345678901234567890")
        XCTAssertEqual(value["small"]?.numberValue?.text, "-0.000000000000000000001")
        XCTAssertEqual(value["int"]?.int64Value, 9_007_199_254_740_993)
        XCTAssertEqual(
            JSONSerializer.string(from: value),
            #"{"big":123456789012345678901234567890,"int":9007199254740993,"small":-0.000000000000000000001}"#
        )
        XCTAssertEqual(try JSONParser.parse(JSONSerializer.string(from: value)), value)
    }

    func testStrictParsing() {
        for bad in [
            #"{"a":1,"a":2}"#,
            #"{"a":01}"#,
            #"{"a":1,}"#,
            #"["\ud800"]"#,
            "[\"\u{01}\"]",
            #"{"a":tru}"#,
            #"{} {}"#,
            #"{"a":"\x"}"#,
            "[1.]",
            "[-]"
        ] {
            XCTAssertThrowsError(try JSONParser.parse(bad), bad)
        }

        let deep = String(repeating: "[", count: 70) + String(repeating: "]", count: 70)
        XCTAssertThrowsError(try JSONParser.parse(deep)) {
            XCTAssertEqual($0 as? JSONParseError, .tooDeep)
        }
        XCTAssertThrowsError(try JSONParser.parse(Data(repeating: 0x20, count: 10), maxBytes: 5)) {
            XCTAssertEqual($0 as? JSONParseError, .tooLarge)
        }
    }

    func testEscapesRoundTrip() throws {
        let value = try JSONParser.parse(#"["\"\\\/\b\f\n\r\té😀", "plain ü"]"#)
        XCTAssertEqual(value.arrayValue?.first?.stringValue, "\"\\/\u{08}\u{0C}\n\r\té😀")
        XCTAssertEqual(try JSONParser.parse(JSONSerializer.string(from: value)), value)
        XCTAssertEqual(JSONSerializer.string(from: .string("a\u{01}b")), #""a\u0001b""#)
    }

    func testObjectKeysAreWrittenSorted() {
        let value = JSONValue.object(["b": .int(1), "a": .array([.null, .bool(false)]), "c": .string("x")])
        XCTAssertEqual(JSONSerializer.string(from: value), #"{"a":[null,false],"b":1,"c":"x"}"#)
    }

    func testAnyCodableRoundTripsWhatTheWalletWrapsAndDecodesPeerParameters() throws {
        let bytes = Data([0, 1, 2, 250, 255])
        XCTAssertEqual(try AnyCodable(bytes).get(Data.self), bytes)
        XCTAssertEqual(try AnyCodable("0x01").get(String.self), "0x01")
        XCTAssertEqual(AnyCodable("0x01").stringRepresentation, #""0x01""#)

        struct Signature: Codable, Equatable {
            let id: UInt
            let signature: String
        }
        let signature = Signature(id: UInt.max - 1, signature: "0xabc")
        let wrapped = AnyCodable(signature)
        XCTAssertEqual(try wrapped.get(Signature.self), signature)
        // Integers beyond 2^53 are written exactly, as `JSONEncoder` writes them.
        XCTAssertEqual(wrapped.value["id"]?.numberValue?.text, String(UInt.max - 1))

        let params = AnyCodable(json: try JSONParser.parse(#"["0x48656c6c6f", "0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb"]"#))
        XCTAssertEqual(try params.get([String].self), ["0x48656c6c6f", "0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb"])

        let encoded = try JSONEncoder().encode(params)
        XCTAssertEqual(try JSONDecoder().decode(AnyCodable.self, from: encoded), params)
    }

    func testRPCMessagesReadAndWrite() throws {
        let request = try XCTUnwrap(RPCMessage(json: try JSONParser.parse(#"{"id":1730000000000123,"jsonrpc":"2.0","method":"wc_sessionPing","params":{}}"#)))
        XCTAssertEqual(request, .request(id: 1_730_000_000_000_123, method: "wc_sessionPing", params: .object([:])))
        XCTAssertEqual(request.text, #"{"id":1730000000000123,"jsonrpc":"2.0","method":"wc_sessionPing","params":{}}"#)

        let error = try XCTUnwrap(RPCMessage(json: try JSONParser.parse(#"{"id":7,"jsonrpc":"2.0","error":{"code":5000,"message":"User rejected."}}"#)))
        XCTAssertEqual(error, .response(id: 7, result: .error(JSONRPCError(code: 5000, message: "User rejected."))))
        XCTAssertNil(RPCMessage(json: try JSONParser.parse(#"{"jsonrpc":"2.0","result":true}"#)))
        XCTAssertNil(RPCMessage(json: try JSONParser.parse(#"{"id":1,"jsonrpc":"2.0","error":{"message":"no code"}}"#)))

        let generator = RPCIdentifierGenerator()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = generator.next(now: now)
        let second = generator.next(now: now)
        XCTAssertGreaterThan(second, first)
        XCTAssertEqual(first / 1000, 1_700_000_000_000)
    }
}

final class PairingLinkTests: XCTestCase {
    private let topic = String(repeating: "ab", count: 32)
    private let symKey = String(repeating: "cd", count: 32)

    func testReadsAVersion2LinkAndWritesTheSameOneBack() throws {
        let link = "wc:\(topic)@2?expiryTimestamp=1700000300&relay-protocol=irn&symKey=\(symKey)"
        let uri = try WalletConnectURI(uriString: link)

        XCTAssertEqual(uri.topic, topic)
        XCTAssertEqual(uri.symKey, symKey)
        XCTAssertEqual(uri.relayProtocol, "irn")
        XCTAssertEqual(uri.expiryTimestamp, 1_700_000_300)
        XCTAssertEqual(uri.absoluteString, link)
        XCTAssertEqual(try WalletConnectURI(uriString: "wc://\(topic)@2?symKey=\(symKey)").relayProtocol, "irn")

        let withMethods = try WalletConnectURI(
            uriString: "wc:\(topic)@2?relay-protocol=irn&symKey=\(symKey)&methods=wc_sessionPropose,wc_sessionAuthenticate"
        )
        XCTAssertEqual(withMethods.methods, ["wc_sessionPropose", "wc_sessionAuthenticate"])
    }

    func testRefusesARetiredVersion1LinkAndAnythingMalformed() {
        XCTAssertThrowsError(try WalletConnectURI(uriString: "wc:\(topic)@1?bridge=https%3A%2F%2Fbridge.example&key=\(symKey)")) {
            XCTAssertEqual($0 as? WalletConnectURI.Error, .retiredVersion)
        }

        for link in [
            "https://example.org",
            "wc:\(topic)@2",
            "wc:\(topic)@2?symKey=short",
            "wc:\(topic)@2?symKey=\(symKey)&relay-protocol=waku",
            "wc:not-a-topic@2?symKey=\(symKey)",
            "wc:\(topic)@2?symKey=\(symKey)&expiryTimestamp=soon",
            "wc:\(topic)@3?symKey=\(symKey)",
            "wc:\(topic)@?symKey=\(symKey)",
            "wc:" + String(repeating: "a", count: 5000)
        ] {
            XCTAssertThrowsError(try WalletConnectURI(uriString: link), link) { error in
                guard case .invalid = error as? WalletConnectURI.Error else {
                    return XCTFail("\(link): \(error)")
                }
            }
        }
    }
}

final class NamespacesTests: XCTestCase {
    private let ethereum = Blockchain("eip155:1")!
    private let polygon = Blockchain("eip155:137")!
    private let polkadot = Blockchain("polkadot:91b171bb158e2d3848fa23a9f1c25182")!
    private let evmAddress = "0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb"
    private let dotAddress = "15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5"

    private func proposal(
        required: [String: ProposalNamespace] = [:],
        optional: [String: ProposalNamespace]? = nil
    ) -> Session.Proposal {
        Session.Proposal(
            id: 1,
            pairingTopic: String(repeating: "a", count: 64),
            proposer: AppMetadata(name: "dApp", description: "", url: "https://dapp.example", icons: []),
            requiredNamespaces: required,
            optionalNamespaces: optional,
            sessionProperties: nil,
            expiryDate: Date().addingTimeInterval(300)
        )
    }

    func testRequiredAndOptionalEntriesMergeIntoOneNamespace() throws {
        let built = try AutoNamespaces.build(
            sessionProposal: proposal(
                required: ["eip155": ProposalNamespace(chains: [ethereum], methods: ["personal_sign"], events: ["chainChanged"])],
                optional: [
                    "eip155:137": ProposalNamespace(methods: ["eth_sendTransaction", "wallet_unknown"], events: []),
                    "polkadot": ProposalNamespace(chains: [polkadot], methods: ["polkadot_signMessage"], events: [])
                ]
            ),
            chains: [ethereum, polygon, polkadot],
            methods: ["personal_sign", "eth_sendTransaction", "polkadot_signMessage"],
            events: ["chainChanged"],
            accounts: [
                Account(blockchain: ethereum, address: evmAddress)!,
                Account(blockchain: polygon, address: evmAddress)!,
                Account(blockchain: polkadot, address: dotAddress)!
            ]
        )

        XCTAssertEqual(Set(built.keys), ["eip155", "polkadot"])
        XCTAssertEqual(built["eip155"]?.chains, [ethereum, polygon])
        XCTAssertEqual(built["eip155"]?.accounts.map(\.absoluteString), ["eip155:1:\(evmAddress)", "eip155:137:\(evmAddress)"])
        XCTAssertEqual(built["eip155"]?.methods, ["personal_sign", "eth_sendTransaction"])
        XCTAssertEqual(built["polkadot"]?.accounts.map(\.address), [dotAddress])
    }

    func testRequiredEntriesMustBeMetInFull() {
        let required = ["eip155": ProposalNamespace(chains: [ethereum, polygon], methods: ["personal_sign"], events: [])]
        let accounts = [Account(blockchain: ethereum, address: evmAddress)!]

        XCTAssertThrowsError(
            try AutoNamespaces.build(sessionProposal: proposal(required: required), chains: [ethereum], methods: ["personal_sign"], events: [], accounts: accounts)
        ) { XCTAssertEqual($0 as? AutoNamespacesError, .requiredChainsNotSatisfied) }

        XCTAssertThrowsError(
            try AutoNamespaces.build(sessionProposal: proposal(required: required), chains: [ethereum, polygon], methods: [], events: [], accounts: accounts)
        ) { XCTAssertEqual($0 as? AutoNamespacesError, .requiredMethodsNotSatisfied) }

        XCTAssertThrowsError(
            try AutoNamespaces.build(
                sessionProposal: proposal(required: ["eip155": ProposalNamespace(chains: [ethereum], methods: [], events: ["accountsChanged"])]),
                chains: [ethereum],
                methods: [],
                events: [],
                accounts: accounts
            )
        ) { XCTAssertEqual($0 as? AutoNamespacesError, .requiredEventsNotSatisfied) }

        XCTAssertThrowsError(
            try AutoNamespaces.build(sessionProposal: proposal(required: required), chains: [ethereum, polygon], methods: ["personal_sign"], events: [], accounts: [])
        ) { XCTAssertEqual($0 as? AutoNamespacesError, .requiredAccountsNotSatisfied) }

        XCTAssertThrowsError(
            try AutoNamespaces.build(
                sessionProposal: proposal(optional: ["solana": ProposalNamespace(chains: [Blockchain("solana:4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ")!], methods: ["solana_signMessage"], events: [])]),
                chains: [ethereum],
                methods: ["personal_sign"],
                events: [],
                accounts: accounts
            )
        ) { XCTAssertEqual($0 as? AutoNamespacesError, .emptySessionNamespacesForbidden) }
    }

    func testAChainScopedRequiredKeyIsGrantedUnderItsNamespace() throws {
        let built = try AutoNamespaces.build(
            sessionProposal: proposal(required: ["eip155:1": ProposalNamespace(methods: ["personal_sign"], events: [])]),
            chains: [ethereum],
            methods: ["personal_sign"],
            events: [],
            accounts: [Account(blockchain: ethereum, address: evmAddress)!]
        )
        XCTAssertEqual(built["eip155"]?.chains, [ethereum])
        XCTAssertTrue(PeerMessageReader.covers(required: ["eip155:1": ProposalNamespace(methods: ["personal_sign"], events: [])], granted: built))
    }

    func testCAIPIdentifiers() {
        XCTAssertEqual(Blockchain("polkadot:91b171bb158e2d3848fa23a9f1c25182")?.reference, "91b171bb158e2d3848fa23a9f1c25182")
        XCTAssertNil(Blockchain("e:1"))
        XCTAssertNil(Blockchain("eip155"))
        XCTAssertNil(Blockchain("EIP155:1"))
        XCTAssertNil(Blockchain("eip155:1:2"))
        XCTAssertEqual(Account("eip155:1:\(evmAddress)")?.address, evmAddress)
        XCTAssertNil(Account("eip155:1:"))
        XCTAssertNil(Account(blockchain: ethereum, address: "has space"))
    }
}
