import XCTest
@testable import fearless

final class IrohaAddressCodecTests: XCTestCase {
    func testEncodesAndParsesTairaAndNexusGoldenVectors() throws {
        for vector in try loadVectors() {
            let iroha = try dictionary(vector["expected"])["iroha"].flatMap(dictionary) ?? [:]
            let taira = try XCTUnwrap(iroha["taira"].flatMap(dictionary))
            let nexus = try XCTUnwrap(iroha["nexus"].flatMap(dictionary))

            XCTAssertEqual(try IrohaAddressCodec.canonicalHex(publicKeyHex: string(taira["publicKeyHex"])), string(taira["canonicalHex"]))
            XCTAssertEqual(try IrohaAddressCodec.canonicalHex(publicKeyHex: string(nexus["publicKeyHex"])), string(nexus["canonicalHex"]))
            XCTAssertEqual(
                try IrohaAddressCodec.encode(
                    publicKeyHex: string(taira["publicKeyHex"]),
                    chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
                ),
                string(taira["i105"])
            )
            XCTAssertEqual(
                try IrohaAddressCodec.encode(
                    publicKeyHex: string(nexus["publicKeyHex"]),
                    chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
                ),
                string(nexus["i105"])
            )

            XCTAssertEqual(
                try IrohaAddressCodec.parse(
                    string(taira["i105"]),
                    expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
                ),
                IrohaAddressDetails(
                    chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant,
                    network: .taira,
                    canonicalHex: string(taira["canonicalHex"]),
                    publicKeyHex: string(taira["publicKeyHex"]),
                    i105: string(taira["i105"])
                )
            )
            XCTAssertEqual(
                try IrohaAddressCodec.parse(
                    string(nexus["i105"]),
                    expectedDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
                ),
                IrohaAddressDetails(
                    chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant,
                    network: .nexus,
                    canonicalHex: string(nexus["canonicalHex"]),
                    publicKeyHex: string(nexus["publicKeyHex"]),
                    i105: string(nexus["i105"])
                )
            )
        }
    }

    func testRejectsNetworkMismatchesAndMalformedI105Literals() throws {
        let vectors = try loadVectors()
        let iroha = try dictionary(vectors[0]["expected"])["iroha"].flatMap(dictionary) ?? [:]
        let taira = try XCTUnwrap(iroha["taira"].flatMap(dictionary))
        let nexus = try XCTUnwrap(iroha["nexus"].flatMap(dictionary))
        let tairaAddress = string(taira["i105"])
        let nexusAddress = string(nexus["i105"])

        assertError(.unexpectedNetworkPrefix) {
            try IrohaAddressCodec.parse(tairaAddress, expectedDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant)
        }
        assertError(.unexpectedNetworkPrefix) {
            try IrohaAddressCodec.parse(nexusAddress, expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant)
        }
        assertError(.checksumMismatch) {
            try IrohaAddressCodec.parse(tamperLastSymbol(tairaAddress), expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant)
        }
        assertError(.invalidI105Char) {
            try IrohaAddressCodec.parse("\(tairaAddress.prefix(8))!\(tairaAddress.dropFirst(9))")
        }
        assertError(.unsupportedAddressFormat) {
            try IrohaAddressCodec.parse(" \(tairaAddress)")
        }
        assertError(.unsupportedAddressFormat) {
            try IrohaAddressCodec.parse(string(taira["canonicalHex"]))
        }
        assertError(.missingI105Sentinel) {
            try IrohaAddressCodec.parse(nexusAddress.replacingOccurrences(of: "sora", with: "\u{ff53}\u{ff4f}\u{ff52}\u{ff41}", options: [.anchored]))
        }
        assertError(.invalidI105Char) {
            try IrohaAddressCodec.parse(nexusAddress.replacingOccurrences(of: "\u{ff9b}", with: "\u{30ed}", options: [.literal]))
        }

        XCTAssertFalse(IrohaAddressCodec.isValid(tamperLastSymbol(tairaAddress), expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant))
        XCTAssertNil(IrohaAddressCodec.networkKind(string(taira["canonicalHex"])))
    }

    func testSupportsCanonicalCustomNumericPrefixesOnly() throws {
        let vectors = try loadVectors()
        let iroha = try dictionary(vectors[0]["expected"])["iroha"].flatMap(dictionary) ?? [:]
        let publicKeyHex = string(try XCTUnwrap(iroha["taira"].flatMap(dictionary))["publicKeyHex"])
        let custom = try IrohaAddressCodec.encode(publicKeyHex: publicKeyHex, chainDiscriminant: 42)

        XCTAssertTrue(custom.hasPrefix("n42"))
        XCTAssertEqual(try IrohaAddressCodec.parse(custom, expectedDiscriminant: 42).network, .custom)
        assertError(.unexpectedNetworkPrefix) {
            try IrohaAddressCodec.parse(custom, expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant)
        }
        assertError(.unsupportedAddressFormat) {
            try IrohaAddressCodec.parse(custom.replacingOccurrences(of: "n42", with: "n00042", options: [.anchored]), expectedDiscriminant: 42)
        }
    }

    func testRejectsInvalidPublicKeysAndDiscriminantsBeforeEncoding() throws {
        let vectors = try loadVectors()
        let iroha = try dictionary(vectors[0]["expected"])["iroha"].flatMap(dictionary) ?? [:]
        let publicKeyHex = string(try XCTUnwrap(iroha["taira"].flatMap(dictionary))["publicKeyHex"])

        assertError(.invalidLength) {
            try IrohaAddressCodec.encode(publicKeyHex: "abcd", chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant)
        }
        assertError(.invalidHexAddress) {
            try IrohaAddressCodec.encode(
                publicKeyHex: "\(publicKeyHex.dropLast())z",
                chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            )
        }
        assertError(.invalidI105Prefix) {
            try IrohaAddressCodec.encode(publicKeyHex: publicKeyHex, chainDiscriminant: -1)
        }
        assertError(.invalidI105Prefix) {
            try IrohaAddressCodec.encode(publicKeyHex: publicKeyHex, chainDiscriminant: 0x4000)
        }
    }

    func testRejectsChecksumValidPayloadsOutsideSingleKeyEd25519Shape() throws {
        let vectors = try loadVectors()
        let iroha = try dictionary(vectors[0]["expected"])["iroha"].flatMap(dictionary) ?? [:]
        let canonicalHex = string(try XCTUnwrap(iroha["taira"].flatMap(dictionary))["canonicalHex"])
        let discriminant = UniversalWalletRegistry.taira.chainDiscriminant

        assertError(.invalidHeaderVersion) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("0x22\(canonicalHex.dropFirst(4))", chainDiscriminant: discriminant))
        }
        assertError(.invalidNormVersion) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("0x00\(canonicalHex.dropFirst(4))", chainDiscriminant: discriminant))
        }
        assertError(.unknownAddressClass) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("0x12\(canonicalHex.dropFirst(4))", chainDiscriminant: discriminant))
        }
        assertError(.unexpectedExtensionFlag) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("0x03\(canonicalHex.dropFirst(4))", chainDiscriminant: discriminant))
        }
        assertError(.unknownControllerTag) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("\(canonicalHex.prefix(4))01\(canonicalHex.dropFirst(6))", chainDiscriminant: discriminant))
        }
        assertError(.unknownCurve) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("\(canonicalHex.prefix(6))02\(canonicalHex.dropFirst(8))", chainDiscriminant: discriminant))
        }
        assertError(.invalidLength) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("\(canonicalHex.prefix(8))1f\(canonicalHex.dropFirst(10))", chainDiscriminant: discriminant))
        }
        assertError(.unexpectedTrailingBytes) {
            try IrohaAddressCodec.parse(IrohaAddressCodec.encodeCanonicalHex("\(canonicalHex)00", chainDiscriminant: discriminant))
        }
    }

    private func loadVectors() throws -> [[String: Any]] {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("docs/universal-wallet-v2-vectors.json")
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(json["vectors"] as? [[String: Any]])
    }

    private func dictionary(_ value: Any?) throws -> [String: Any] {
        try XCTUnwrap(value as? [String: Any])
    }

    private func string(_ value: Any?) -> String {
        value as? String ?? ""
    }

    private func assertError(
        _ expected: IrohaAddressErrorCode,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ action: () throws -> Void
    ) {
        do {
            try action()
            XCTFail("Expected IrohaAddressError", file: file, line: line)
        } catch let error as IrohaAddressError {
            XCTAssertEqual(error.code, expected, file: file, line: line)
        } catch {
            XCTFail("Expected IrohaAddressError, got \(error)", file: file, line: line)
        }
    }

    private func tamperLastSymbol(_ address: String) -> String {
        "\(address.dropLast())\(address.hasSuffix("1") ? "2" : "1")"
    }
}
