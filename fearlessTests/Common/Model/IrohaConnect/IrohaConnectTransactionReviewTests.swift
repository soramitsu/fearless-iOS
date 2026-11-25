import CryptoKit
import XCTest
@testable import fearless

final class IrohaConnectTransactionReviewTests: XCTestCase {
    private typealias Vectors = IrohaConnectWebVectors

    // MARK: - The web wallet's verdicts

    /// Every payload the web wallet reviewed (SDK-built transfers and contract calls, and refused variants) gets the
    /// same verdict on iOS: the same review and payload hash, or the same refusal code.
    func testReview_whenGivenTheWebPayloads_thenReachesTheSameVerdict() throws {
        let cases = try XCTUnwrap(Vectors.root["transactions"] as? [[String: Any]])
        XCTAssertEqual(cases.count, 20)
        var accepted = 0
        for entry in cases {
            let name = entry["name"] as? String ?? ""
            let payload = try XCTUnwrap(Data(irohaConnectHex: entry["payloadHex"] as? String ?? ""), name)
            let expectation = try self.expectation(entry["expectation"] as? [String: Any] ?? [:])
            let result = try XCTUnwrap(entry["result"] as? [String: Any], name)

            if result["ok"] as? Bool == true {
                accepted += 1
                let reviewed = try IrohaConnectTransactionReviewer.review(payload, expectation: expectation)
                XCTAssertEqual(reviewed.payloadHash.irohaConnectHex, result["payloadHashHex"] as? String, name)
                Self.assertReview(reviewed.review, equals: result["review"] as? [String: Any] ?? [:], name: name)
            } else {
                XCTAssertThrowsError(try IrohaConnectTransactionReviewer.review(payload, expectation: expectation), name) { error in
                    XCTAssertEqual((error as? IrohaConnectTransactionError)?.code, result["code"] as? String, "\(name): \(error)")
                }
            }
        }
        XCTAssertEqual(accepted, 7)
    }

    func testReview_whenAPayloadByteChanges_thenTheHashOrVerdictChanges() throws {
        let entry = try transactionVector("transfer xor")
        let payload = try XCTUnwrap(Data(irohaConnectHex: entry["payloadHex"] as? String ?? ""))
        let expectation = try self.expectation(entry["expectation"] as? [String: Any] ?? [:])
        let original = try IrohaConnectTransactionReviewer.review(payload, expectation: expectation)
        XCTAssertEqual(original.payloadHash.last.map { $0 & 1 }, 1, "the payload hash carries Iroha's marker bit")

        var refused = 0
        for index in stride(from: 0, to: payload.count, by: 7) {
            var mutated = payload
            mutated[index] ^= 0x01
            if let reviewed = try? IrohaConnectTransactionReviewer.review(mutated, expectation: expectation) {
                XCTAssertNotEqual(reviewed.payloadHash, original.payloadHash)
                XCTAssertNotEqual(reviewed.review, original.review, "byte \(index) changed the hash but not the review")
            } else {
                refused += 1
            }
        }
        XCTAssertGreaterThan(refused, 0)
    }

    func testReview_whenTheSigningKeyIsNotTheAuthority_thenRefuses() throws {
        let entry = try transactionVector("transfer xor")
        let payload = try XCTUnwrap(Data(irohaConnectHex: entry["payloadHex"] as? String ?? ""))
        let vector = try expectation(entry["expectation"] as? [String: Any] ?? [:])
        let expectation = IrohaConnectTransactionExpectation(
            networkID: vector.networkID,
            networkPrefix: vector.networkPrefix,
            authority: vector.authority,
            signingPublicKey: Data(repeating: 9, count: 32)
        )
        XCTAssertThrowsError(try IrohaConnectTransactionReviewer.review(payload, expectation: expectation)) {
            XCTAssertEqual(($0 as? IrohaConnectTransactionError)?.code, "invalid_transaction")
        }
    }

    func testReview_whenAMantissaIsNotMinimal_thenRefuses() throws {
        // 0.001 written with a two-byte mantissa [1, 0]: the same value, not the codec's encoding.
        let entry = try transactionVector("transfer xor")
        let payload = try XCTUnwrap(Data(irohaConnectHex: entry["payloadHex"] as? String ?? ""))
        let expectation = try self.expectation(entry["expectation"] as? [String: Any] ?? [:])
        XCTAssertEqual(IrohaPayloadEncoder.twosComplementBytes(1), Data([1]))
        XCTAssertEqual(IrohaPayloadEncoder.twosComplementBytes(0x80), Data([0x80, 0]))
        XCTAssertEqual(IrohaPayloadEncoder.twosComplementBytes(0), Data())
        let minimal = IrohaPayloadEncoder.structure([IrohaPayloadEncoder.u32(1) + Data([1]), IrohaPayloadEncoder.u32(3)])
        XCTAssertNotNil(payload.range(of: minimal))
        // Widening the mantissa shifts every enclosing length, so the decoder already refuses the payload.
        var widened = payload
        if let range = payload.range(of: minimal) {
            widened.replaceSubrange(range, with: IrohaPayloadEncoder.structure([IrohaPayloadEncoder.u32(2) + Data([1, 0]), IrohaPayloadEncoder.u32(3)]))
        }
        XCTAssertThrowsError(try IrohaConnectTransactionReviewer.review(widened, expectation: expectation))
    }

    // MARK: - Primitives

    func testBlake3_whenGivenOfficialPatternInputs_thenMatchesTheReference() throws {
        let vectors = try XCTUnwrap(Vectors.section("primitives")["blake3"] as? [[String: Any]])
        for vector in vectors {
            let length = try XCTUnwrap(vector["length"] as? Int)
            let input = Data((0 ..< length).map { UInt8($0 % 251) })
            XCTAssertEqual(IrohaBlake3.hash(input)?.irohaConnectHex, vector["digestHex"] as? String, "length \(length)")
        }
        XCTAssertNil(IrohaBlake3.hash(Data(count: 1025)))
    }

    func testSanitize_whenTextHasControlBidiOrLineSeparators_thenEscapesLikeTheWeb() throws {
        let vectors = try XCTUnwrap(Vectors.section("primitives")["sanitize"] as? [[String: Any]])
        for vector in vectors {
            let input = try XCTUnwrap(vector["input"] as? String)
            XCTAssertEqual(irohaConnectSanitizedReviewText(input), vector["output"] as? String, input)
        }
    }

    func testAssetDefinitionID_whenTairaXor_thenRendersTheCanonicalBase58Literal() throws {
        let entry = try transactionVector("transfer xor")
        let result = try XCTUnwrap(entry["result"] as? [String: Any])
        let review = try XCTUnwrap(result["review"] as? [String: Any])
        let transfer = try XCTUnwrap(review["transfer"] as? [String: Any])
        let asset = try XCTUnwrap(transfer["asset"] as? [String: Any])
        XCTAssertEqual(asset["definitionId"] as? String, UniversalWalletRegistry.tairaNativeXorAssetDefinitionId)
        XCTAssertEqual(IrohaBase58.encode(Data([0, 0, 1])), "112")
        XCTAssertEqual(IrohaBase58.encode(Data("hello world".utf8)), "StV1DL6CwTryKyV")
    }

    func testContractAddress_whenNotExactCanonicalBech32m_thenRefuses() {
        let canonical = "irohac1qyqqqqqqqqqqqq95fes93ygegsv5enq9mqsz6x4lv4vp9gg4yxgjw"
        XCTAssertTrue(IrohaContractAddress.isCanonical(canonical))
        XCTAssertFalse(IrohaContractAddress.isCanonical(canonical.uppercased()))
        XCTAssertFalse(IrohaContractAddress.isCanonical(String(canonical.dropLast()) + "q"))
        XCTAssertFalse(IrohaContractAddress.isCanonical(canonical.replacingOccurrences(of: "irohac1", with: "iroha1")))
        XCTAssertFalse(IrohaContractAddress.isCanonical(""))
    }

    func testEd25519PublicKey_whenNotAStrictPrimeOrderPoint_thenRefuses() throws {
        let valid = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation
        XCTAssertTrue(IrohaEd25519PublicKey.isValid(valid))
        XCTAssertTrue(IrohaEd25519PublicKey.isValid(Vectors.sessionAccount.publicKey))
        // The identity point and the order-2 point are small-order.
        XCTAssertFalse(IrohaEd25519PublicKey.isValid(Data([1] + [UInt8](repeating: 0, count: 31))))
        var orderTwo = [UInt8](repeating: 0xFF, count: 32)
        orderTwo[0] = 0xEC
        orderTwo[31] = 0x7F
        XCTAssertFalse(IrohaEd25519PublicKey.isValid(Data(orderTwo)))
        // y >= p is not canonical.
        XCTAssertFalse(IrohaEd25519PublicKey.isValid(Data(repeating: 0xFF, count: 31) + Data([0x7F])))
        // y = 2 is not on the curve.
        XCTAssertFalse(IrohaEd25519PublicKey.isValid(Data([2] + [UInt8](repeating: 0, count: 31))))
        XCTAssertFalse(IrohaEd25519PublicKey.isValid(Data(count: 31)))
    }

    func testMetadataJSON_whenNotTheCodecsCanonicalSpelling_thenRefuses() throws {
        let accepted = [
            "null", "true", "false", "0", "-5", "9007199254740991", "\"\"", "\"a\\\"b\\\\c\\n\\u001f\"", "\"桜\"",
            "[]", "{}", "[1,true,null]", "{\"a\":\"x\",\"b\":[1]}", "{\"Z\":1,\"a\":2}"
        ]
        for text in accepted {
            var parser = IrohaMetadataJSON.Parser(text: text)
            let value = try parser.parseDocument()
            XCTAssertEqual(IrohaMetadataJSON.canonical(value), text, text)
        }
        let refused = [
            " 1", "1 ", "01", "-0", "1.0", "1e2", "9007199254740992", "\"\\u0041\"", "\"\\/\"", "\"\\u000a\"",
            "\"\\u001F\"", "{\"b\":1,\"a\":2}", "{\"a\":1,\"a\":2}", "[1, 2]", "{\"a\" :1}", "nul", "\"x", "[1,]", ""
        ]
        for text in refused {
            var parser = IrohaMetadataJSON.Parser(text: text)
            XCTAssertThrowsError(try parser.parseDocument(), text)
        }
        XCTAssertThrowsError(try IrohaMetadataJSON.validateKey("has space", context: "key"))
        XCTAssertThrowsError(try IrohaMetadataJSON.validateKey("a#b", context: "key"))
        XCTAssertThrowsError(try IrohaMetadataJSON.validateKey("e\u{301}", context: "key"))
        XCTAssertNoThrow(try IrohaMetadataJSON.validateKey("\u{e9}", context: "key"))
        XCTAssertThrowsError(try IrohaMetadataJSON.canonicalArchive([("gas_limit", "1")], legacyKeys: ["gas_limit"]))
        XCTAssertEqual(
            IrohaMetadataJSON.displayText([("10", "1"), ("9", "2"), ("a", "{\"2\":1,\"b\":2}")]),
            "{\"9\":2,\"10\":1,\"a\":{\"2\":1,\"b\":2}}"
        )
    }

    func testPayloadReader_whenALengthIsNotCanonicalLEB128_thenRefuses() throws {
        var reader = IrohaPayloadReader(Data([0x81, 0x00, 0x00]), label: "x")
        XCTAssertThrowsError(try reader.readField("f"))
        var short = IrohaPayloadReader(Data([0x05, 1, 2]), label: "x")
        XCTAssertThrowsError(try short.readField("f"))
        var exact = IrohaPayloadReader(IrohaPayloadEncoder.field(Data(repeating: 7, count: 200)), label: "x")
        XCTAssertEqual(try exact.readField("f"), Data(repeating: 7, count: 200))
        XCTAssertNoThrow(try exact.done())
        XCTAssertEqual(IrohaPayloadEncoder.compactLength(127), Data([0x7F]))
        XCTAssertEqual(IrohaPayloadEncoder.compactLength(128), Data([0x80, 0x01]))
    }

    // MARK: - Helpers

    private func transactionVector(_ name: String) throws -> [String: Any] {
        let cases = try XCTUnwrap(Vectors.root["transactions"] as? [[String: Any]])
        return try XCTUnwrap(cases.first { $0["name"] as? String == name })
    }

    private func expectation(_ json: [String: Any]) throws -> IrohaConnectTransactionExpectation {
        try IrohaConnectTransactionExpectation(
            networkID: IrohaConnectNetworkID.parse(XCTUnwrap(json["networkId"] as? String)),
            networkPrefix: XCTUnwrap(json["networkPrefix"] as? Int),
            authority: XCTUnwrap(json["authority"] as? String),
            signingPublicKey: XCTUnwrap(Data(irohaConnectHex: json["signingPublicKeyHex"] as? String ?? ""))
        )
    }

    /// Compares an iOS review with the web review's JSON field by field.
    static func assertReview(
        _ review: IrohaConnectTransactionReview,
        equals json: [String: Any],
        name: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        func check(_ actual: Any?, _ expected: Any?, _ field: String) {
            XCTAssertEqual(actual.map { "\($0)" }, (expected is NSNull ? nil : expected).map { "\($0)" }, "\(name) \(field)", file: file, line: line)
        }
        func checkAsset(_ asset: IrohaConnectReviewAsset, _ json: [String: Any]?, _ field: String) {
            check(asset.definitionID, json?["definitionId"], "\(field).definitionId")
            check(asset.symbol, json?["symbol"], "\(field).symbol")
        }
        check(review.kind.rawValue, json["kind"], "kind")
        check(review.authority, json["authority"], "authority")
        check(review.networkID, json["networkId"], "networkId")
        check(review.payloadBytes, json["payloadBytes"], "payloadBytes")
        check(review.payloadHashHex, json["payloadHashHex"], "payloadHashHex")
        check(review.creationTimeMs, json["creationTimeMs"], "creationTimeMs")
        check(review.ttlMs, json["ttlMs"], "ttlMs")
        check(review.nonce, json["nonce"], "nonce")
        check(review.metadata, json["metadata"], "metadata")

        let fee = json["fee"] as? [String: Any] ?? [:]
        check(review.fee.payer.rawValue, fee["payer"], "fee.payer")
        check(review.fee.program, fee["program"], "fee.program")
        check(review.fee.programRevision, fee["programRevision"], "fee.programRevision")
        check(review.fee.gasLimit, fee["gasLimit"], "fee.gasLimit")
        let limits = fee["chargeLimits"] as? [[String: Any]] ?? []
        XCTAssertEqual(review.fee.chargeLimits.count, limits.count, "\(name) fee.chargeLimits", file: file, line: line)
        for (limit, expected) in zip(review.fee.chargeLimits, limits) {
            check(limit.kind.rawValue, expected["kind"], "fee.kind")
            check(limit.maxAmount, expected["maxAmount"], "fee.maxAmount")
            checkAsset(limit.asset, expected["asset"] as? [String: Any], "fee.asset")
        }

        let transfer = json["transfer"] as? [String: Any]
        XCTAssertEqual(review.transfer == nil, transfer == nil, "\(name) transfer", file: file, line: line)
        if let actual = review.transfer, let transfer {
            checkAsset(actual.asset, transfer["asset"] as? [String: Any], "transfer.asset")
            check(actual.scope, transfer["scope"], "transfer.scope")
            check(actual.quantity, transfer["quantity"], "transfer.quantity")
            check(actual.destination, transfer["destination"], "transfer.destination")
        }

        let calls = json["calls"] as? [[String: Any]]
        XCTAssertEqual(review.calls?.count, calls?.count, "\(name) calls", file: file, line: line)
        for (call, expected) in zip(review.calls ?? [], calls ?? []) {
            check(call.contractAddress, expected["contractAddress"], "call.contractAddress")
            check(call.entrypoint, expected["entrypoint"], "call.entrypoint")
            check(call.codeHashHex, expected["codeHashHex"], "call.codeHashHex")
            check(call.argumentBytes, expected["argumentBytes"], "call.argumentBytes")
            check(call.argumentsSHA256, expected["argumentsSha256"], "call.argumentsSha256")
        }
    }
}
