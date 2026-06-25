import XCTest
@testable import fearless

final class SolanaTransactionSignerTests: XCTestCase {
    func testParsesAndSignsLegacySerializedSolanaTransactions() throws {
        let fixture = try loadFixture()
        let vector = try XCTUnwrap(fixture.vectors.first)
        let expected = try XCTUnwrap(vector.expected["solana"] as? [String: Any])
        let raw = try XCTUnwrap(Data(base64Encoded: Self.legacyRawBase64))
        let expectedPublicKey = try XCTUnwrap(expected["publicKeyHex"] as? String).hexToData()

        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(raw)
        let signed = try SolanaTransactionSigner.signSerializedTransaction(
            mnemonic: vector.mnemonic,
            transaction: raw,
            expectedSigner: try XCTUnwrap(expected["address"] as? String)
        )

        XCTAssertEqual(parsed.version, .legacy)
        XCTAssertEqual(parsed.requiredSignatures, 1)
        XCTAssertEqual(parsed.accountKeys, [try XCTUnwrap(expected["address"] as? String), Self.systemProgram])
        XCTAssertEqual(parsed.addressTableLookupCount, 0)
        XCTAssertEqual(parsed.instructionCount, 1)
        XCTAssertEqual(parsed.readonlySignedAccounts, 0)
        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 1)
        XCTAssertEqual(signed.version, .legacy)
        XCTAssertEqual(signed.signer, expected["address"] as? String)
        XCTAssertFalse(signed.signatureBase58.isEmpty)
        XCTAssertEqual(signed.signedTransactionBase64, signed.signedTransaction.base64EncodedString())
        XCTAssertEqual(
            signed.signedTransaction.subdata(in: parsed.messageOffset ..< signed.signedTransaction.count),
            parsed.messageBytes
        )

        let insertedSignature = signed.signedTransaction.subdata(
            in: parsed.signaturesOffset ..< parsed.signaturesOffset + 64
        )
        XCTAssertEqual(insertedSignature.count, 64)
        XCTAssertNotEqual(insertedSignature, Data(repeating: 0, count: 64))
        XCTAssertTrue(try SolanaSigner.verifyMessage(
            publicKey: expectedPublicKey,
            message: parsed.messageBytes,
            signature: insertedSignature
        ))
        XCTAssertFalse(try SolanaSigner.verifyMessage(
            publicKey: expectedPublicKey,
            message: parsed.messageBytes + Data([0]),
            signature: insertedSignature
        ))
    }

    func testParsesAndSignsV0SerializedSolanaTransactionsFromBase64() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["solana"] as? [String: Any])
        let expectedPublicKey = try XCTUnwrap(expected["publicKeyHex"] as? String).hexToData()

        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(base64: Self.v0RawBase64)
        let signed = try SolanaTransactionSigner.signSerializedTransaction(
            mnemonic: vector.mnemonic,
            transactionBase64: Self.v0RawBase64
        )

        XCTAssertEqual(parsed.version, .v0)
        XCTAssertEqual(parsed.addressTableLookupCount, 0)
        XCTAssertEqual(parsed.instructionCount, 0)
        XCTAssertEqual(signed.version, .v0)
        XCTAssertEqual(signed.signer, expected["address"] as? String)
        XCTAssertFalse(signed.signatureBase58.isEmpty)
        XCTAssertEqual(signed.signedTransactionBase64, signed.signedTransaction.base64EncodedString())
        XCTAssertEqual(
            signed.signedTransaction.subdata(in: parsed.messageOffset ..< signed.signedTransaction.count),
            parsed.messageBytes
        )

        let insertedSignature = signed.signedTransaction.subdata(
            in: parsed.signaturesOffset ..< parsed.signaturesOffset + 64
        )
        XCTAssertEqual(insertedSignature.count, 64)
        XCTAssertNotEqual(insertedSignature, Data(repeating: 0, count: 64))
        XCTAssertTrue(try SolanaSigner.verifyMessage(
            publicKey: expectedPublicKey,
            message: parsed.messageBytes,
            signature: insertedSignature
        ))
        XCTAssertFalse(try SolanaSigner.verifyMessage(
            publicKey: expectedPublicKey,
            message: parsed.messageBytes + Data([0]),
            signature: insertedSignature
        ))
    }

    func testRejectsMalformedSolanaTransactionEnvelopesAndSignerStates() throws {
        let fixture = try loadFixture()
        let vector = try XCTUnwrap(fixture.vectors.first)
        let otherVector = try XCTUnwrap(fixture.vectors.dropFirst().first)
        let expected = try XCTUnwrap(vector.expected["solana"] as? [String: Any])
        let otherExpected = try XCTUnwrap(otherVector.expected["solana"] as? [String: Any])
        let expectedPublicKey = try XCTUnwrap(expected["publicKeyHex"] as? String).hexToData()

        assertTransactionError(.emptyTransaction) {
            _ = try SolanaTransactionSigner.parseSerializedTransaction(Data())
        }
        assertTransactionError(.invalidTransactionBase64) {
            _ = try SolanaTransactionSigner.parseSerializedTransaction(base64: "*not-base64*")
        }
        assertTransactionError(.missingSignatureSlot) {
            _ = try SolanaTransactionSigner.parseSerializedTransaction(Data([0]))
        }
        assertTransactionError(.truncatedSignatures) {
            _ = try SolanaTransactionSigner.parseSerializedTransaction(Data([1, 2, 3]))
        }
        assertTransactionError(.unsupportedTransactionVersion) {
            _ = try SolanaTransactionSigner.parseSerializedTransaction(Self.transaction(message: Data([0x81, 1, 0, 0])))
        }
        assertTransactionError(.signerMismatch) {
            _ = try SolanaTransactionSigner.signSerializedTransaction(
                mnemonic: vector.mnemonic,
                transaction: try XCTUnwrap(Data(base64Encoded: Self.legacyRawBase64)),
                expectedSigner: try XCTUnwrap(otherExpected["address"] as? String)
            )
        }
        assertTransactionError(.signerNotFound) {
            _ = try SolanaTransactionSigner.signSerializedTransaction(
                mnemonic: otherVector.mnemonic,
                transaction: try XCTUnwrap(Data(base64Encoded: Self.legacyRawBase64))
            )
        }
        assertTransactionError(.signerNotRequired) {
            _ = try SolanaTransactionSigner.signSerializedTransaction(
                mnemonic: vector.mnemonic,
                transaction: Self.transaction(message: Self.legacyMessage(accountKeys: [Data(repeating: 0, count: 32), expectedPublicKey]))
            )
        }
    }

    private func loadFixture() throws -> UniversalWalletFixture {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("docs/universal-wallet-v2-vectors.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(UniversalWalletFixture.self, from: data)
    }

    private func assertTransactionError(
        _ expected: SolanaTransactionSignerError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) {
        XCTAssertThrowsError(try block(), file: file, line: line) { error in
            XCTAssertEqual(error as? SolanaTransactionSignerError, expected, file: file, line: line)
        }
    }

    private static func transaction(message: Data) -> Data {
        Data([1]) + Data(repeating: 0, count: 64) + message
    }

    private static func legacyMessage(accountKeys: [Data], requiredSignatures: Int = 1) -> Data {
        let readonlyUnsignedAccounts = accountKeys.count > requiredSignatures ? 1 : 0

        var message = Data([UInt8(requiredSignatures), 0, UInt8(readonlyUnsignedAccounts)])
        message.append(compact(accountKeys.count))
        accountKeys.forEach { message.append($0) }
        message.append(Data(repeating: 9, count: 32))
        message.append(compact(1))
        message.append(Data([1]))
        message.append(compact(1))
        message.append(Data([0]))
        message.append(compact(0))
        return message
    }

    private static func compact(_ value: Int) -> Data {
        var result = Data()
        var next = value

        repeat {
            var byte = next & 0x7f
            next >>= 7
            if next > 0 {
                byte |= 0x80
            }
            result.append(UInt8(byte))
        } while next > 0

        return result
    }

    private static let systemProgram = "11111111111111111111111111111111"
    private static let legacyRawBase64 = "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAEC8DYnYkanW53jNJ7UKxXiMvZRj8IPX81PHWToH5vSWPcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJAQEBAAA="
    private static let v0RawBase64 = "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAQABAvA2J2JGp1ud4zSe1CsV4jL2UY/CD1/NTx1k6B+b0lj3AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwAA"
}

private extension String {
    func hexToData() -> Data {
        var output = Data()
        var index = startIndex

        while index < endIndex {
            let next = self.index(index, offsetBy: 2)
            output.append(UInt8(self[index ..< next], radix: 16)!)
            index = next
        }

        return output
    }
}

private struct UniversalWalletFixture: Decodable {
    let vectors: [UniversalWalletVector]
}

private struct UniversalWalletVector: Decodable {
    let mnemonic: String
    let expected: [String: Any]

    private enum CodingKeys: String, CodingKey {
        case mnemonic
        case expected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mnemonic = try container.decode(String.self, forKey: .mnemonic)
        expected = try container.decodeJSONDictionary(forKey: .expected)
    }
}

private extension KeyedDecodingContainer {
    func decodeJSONDictionary(forKey key: Key) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: decodeRawJSONObject(forKey: key), options: [])
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    func decodeRawJSONObject(forKey key: Key) throws -> Any {
        let value = try decode(AnyDecodable.self, forKey: key)
        return value.value
    }
}

private struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var dictionary: [String: Any] = [:]
            for key in container.allKeys {
                dictionary[key.stringValue] = try container.decode(AnyDecodable.self, forKey: key).value
            }
            value = dictionary
        } else if var container = try? decoder.unkeyedContainer() {
            var array: [Any] = []
            while !container.isAtEnd {
                array.append(try container.decode(AnyDecodable.self).value)
            }
            value = array
        } else {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self.value = value
            } else if let value = try? container.decode(Int.self) {
                self.value = value
            } else if let value = try? container.decode(Bool.self) {
                self.value = value
            } else if container.decodeNil() {
                value = NSNull()
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
            }
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
