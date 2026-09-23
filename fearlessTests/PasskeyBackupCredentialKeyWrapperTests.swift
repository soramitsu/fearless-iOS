import CryptoKit
import XCTest
@testable import fearless

final class PasskeyBackupCredentialKeyWrapperTests: XCTestCase {
    private let prfSalt = Data(repeating: 0x33, count: 32)
    private let hkdfSalt = Data(repeating: 0x44, count: 32)
    private let nonce = Data(repeating: 0x55, count: 12)
    private let prfOutput = Data(repeating: 0x66, count: 32)
    private let backupKey = Data(repeating: 0x77, count: 32)
    private let wrapper = PasskeyBackupCredentialKeyWrapper()

    func testExactAndroidNodeContextHKDFAndCiphertextVector() throws {
        let context = try context()
        XCTAssertEqual(context.canonicalBytes().count, 204)
        XCTAssertEqual(
            hex(Data(SHA256.hash(data: context.canonicalBytes()))),
            "8904743b6310afddbf7dec05ae3a4f6d1de438a0a51847eb598e5fe55bce93e3"
        )
        let key = try wrapper.deriveKey(prfOutput: prfOutput, prfSalt: prfSalt, hkdfSalt: hkdfSalt, context: context)
        XCTAssertEqual(
            key.withUnsafeBytes { hex(Data($0)) },
            "a70d98717014284aa2932615c28fb61152e8e20606303ce48b9fc2968b2d3d60"
        )
        let aad = PasskeyBackupCredentialKeyWrapper.additionalAuthenticatedData(
            context: context, prfSalt: prfSalt, hkdfSalt: hkdfSalt
        )
        XCTAssertEqual(
            hex(Data(SHA256.hash(data: aad))),
            "075cee5e8cb5eb7509aee51b05a8b6a1e7c4bdcf0df394577328939e23c2a27f"
        )
        let record = try fixedRecord()
        XCTAssertEqual(
            base64URL(record.ciphertextAndTag),
            "m_xnd6ezMk5VjmGJjqjAVrBDJYQTp7NxcktIT8CmyM8uzo4ZphIMYP-2QRflGgs5"
        )
        XCTAssertEqual(try wrapper.unwrap(record: record, prfOutput: prfOutput, expectedContext: context), backupKey)
    }

    func testOpensFixedForeignVectorWithoutCallingLocalWrap() throws {
        let context = try context()
        let record = try PasskeyBackupCredentialKeyWrapperRecord(
            context: context, prfSalt: prfSalt, hkdfSalt: hkdfSalt, nonce: nonce,
            ciphertextAndTag: PasskeyBackupContract.decodeBase64URL(
                "m_xnd6ezMk5VjmGJjqjAVrBDJYQTp7NxcktIT8CmyM8uzo4ZphIMYP-2QRflGgs5"
            )
        )
        XCTAssertEqual(try wrapper.unwrap(record: record, prfOutput: prfOutput, expectedContext: context), backupKey)
    }

    func testCanonicalWireMatchesAndroidHashAndDecodesWithExpectedContext() throws {
        let record = try fixedRecord()
        let encoded = wrapper.encodeRecord(record)
        XCTAssertEqual(encoded.count, 344)
        XCTAssertEqual(
            hex(Data(SHA256.hash(data: encoded))),
            "2ac784e30e93efb4a7fe2505724e1c67ae6f4f16e9aa834029e0bb08c27509dc"
        )
        let decoded = try wrapper.decodeRecord(encoded, expectedContext: record.context)
        XCTAssertEqual(wrapper.encodeRecord(decoded), encoded)
        XCTAssertEqual(
            try wrapper.unwrap(record: decoded, prfOutput: prfOutput, expectedContext: record.context),
            backupKey
        )
        let prefixed = Data([0]) + encoded
        XCTAssertEqual(
            wrapper.encodeRecord(try wrapper.decodeRecord(prefixed.dropFirst(), expectedContext: record.context)),
            encoded
        )
    }

    func testWireRejectsTruncationTrailingBytesVersionsAndContextSubstitution() throws {
        let record = try fixedRecord()
        let encoded = wrapper.encodeRecord(record)
        for length in 0 ..< encoded.count {
            XCTAssertThrowsError(try wrapper.decodeRecord(encoded.prefix(length), expectedContext: record.context))
        }
        XCTAssertThrowsError(try wrapper.decodeRecord(encoded + Data([0]), expectedContext: record.context))
        for index in 0 ..< 220 {
            var changed = encoded
            changed[index] ^= 1
            XCTAssertThrowsError(try wrapper.decodeRecord(changed, expectedContext: record.context))
        }
        XCTAssertThrowsError(try wrapper.decodeRecord(encoded, expectedContext: context(epoch: 8)))
        var hostileLength = encoded
        hostileLength.replaceSubrange(12 ..< 16, with: Data(repeating: 0xFF, count: 4))
        XCTAssertThrowsError(try wrapper.decodeRecord(hostileLength, expectedContext: record.context))
    }

    func testWireDecodingDoesNotTreatCiphertextAsAuthenticatedBeforeUnwrap() throws {
        let record = try fixedRecord()
        var encoded = wrapper.encodeRecord(record)
        encoded[encoded.count - 1] ^= 1
        let decoded = try wrapper.decodeRecord(encoded, expectedContext: record.context)
        XCTAssertThrowsError(
            try wrapper
                .unwrap(record: decoded, prfOutput: prfOutput, expectedContext: record.context)
        ) {
            XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .authenticationFailed)
        }
    }

    func testRejectsEveryMismatchedExpectedContextField() throws {
        let record = try fixedRecord()
        let changed = try [
            context(owner: "owner:" + base64URL(Data(repeating: 0x12, count: 32))),
            context(credential: base64URL(Data(repeating: 0x23, count: 32))),
            context(epoch: 8), context(storageKey: "wallet-5678"), context(walletID: "wallet-002"),
            context(email: "bob@example.com"), context(createdAt: 1_767_225_600_001)
        ]
        for expected in changed {
            XCTAssertThrowsError(try wrapper.unwrap(record: record, prfOutput: prfOutput, expectedContext: expected)) {
                XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .contextMismatch)
            }
        }
    }

    func testTamperedRecordContextFailsAuthenticationEvenWhenCallerAcceptsThatContext() throws {
        let original = try fixedRecord()
        let changed = try context(epoch: 8)
        let tampered = try PasskeyBackupCredentialKeyWrapperRecord(
            context: changed, prfSalt: original.prfSalt, hkdfSalt: original.hkdfSalt,
            nonce: original.nonce, ciphertextAndTag: original.ciphertextAndTag
        )
        XCTAssertThrowsError(try wrapper.unwrap(record: tampered, prfOutput: prfOutput, expectedContext: changed)) {
            XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .authenticationFailed)
        }
    }

    func testRejectsWrongPRFAndEveryTamperedCiphertextSaltNonceOrTagByte() throws {
        let record = try fixedRecord()
        XCTAssertThrowsError(try wrapper.unwrap(
            record: record, prfOutput: Data(repeating: 0x67, count: 32), expectedContext: record.context
        )) { XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .authenticationFailed) }
        for field in ["prfSalt", "hkdfSalt", "nonce", "ciphertextAndTag"] {
            let values = ["prfSalt": record.prfSalt, "hkdfSalt": record.hkdfSalt,
                          "nonce": record.nonce, "ciphertextAndTag": record.ciphertextAndTag]
            for index in try XCTUnwrap(values[field]).indices {
                var changed = values
                var bytes = try XCTUnwrap(changed[field])
                bytes[index] ^= 1
                changed[field] = bytes
                let tampered = try PasskeyBackupCredentialKeyWrapperRecord(
                    context: record.context, prfSalt: XCTUnwrap(changed["prfSalt"]),
                    hkdfSalt: XCTUnwrap(changed["hkdfSalt"]), nonce: XCTUnwrap(changed["nonce"]),
                    ciphertextAndTag: XCTUnwrap(changed["ciphertextAndTag"])
                )
                XCTAssertThrowsError(try wrapper.unwrap(
                    record: tampered, prfOutput: prfOutput, expectedContext: record.context
                )) { XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .authenticationFailed) }
            }
        }
    }

    func testWrapRejectsWrongSecretSaltAndNonceLengths() throws {
        for field in ["backupKey", "prfOutput", "prfSalt", "hkdfSalt", "nonce"] {
            for count in [0, 11, 13, 31, 33, 64] {
                var values = ["backupKey": backupKey, "prfOutput": prfOutput,
                              "prfSalt": prfSalt, "hkdfSalt": hkdfSalt, "nonce": nonce]
                values[field] = Data(repeating: 1, count: count)
                XCTAssertThrowsError(try wrapper.wrapWithParameters(
                    backupKey: XCTUnwrap(values["backupKey"]), prfOutput: XCTUnwrap(values["prfOutput"]),
                    prfSalt: XCTUnwrap(values["prfSalt"]), hkdfSalt: XCTUnwrap(values["hkdfSalt"]),
                    nonce: XCTUnwrap(values["nonce"]), context: context()
                )) { XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .invalidInputLength) }
            }
        }
    }

    func testRecordAndUnwrapRejectInvalidLengths() throws {
        let record = try fixedRecord()
        for field in ["prfSalt", "hkdfSalt", "nonce", "ciphertextAndTag"] {
            var values = ["prfSalt": prfSalt, "hkdfSalt": hkdfSalt,
                          "nonce": nonce, "ciphertextAndTag": record.ciphertextAndTag]
            values[field] = Data()
            XCTAssertThrowsError(try PasskeyBackupCredentialKeyWrapperRecord(
                context: context(), prfSalt: XCTUnwrap(values["prfSalt"]), hkdfSalt: XCTUnwrap(values["hkdfSalt"]),
                nonce: XCTUnwrap(values["nonce"]), ciphertextAndTag: XCTUnwrap(values["ciphertextAndTag"])
            )) { XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .invalidInputLength) }
        }
        XCTAssertThrowsError(try wrapper.unwrap(record: record, prfOutput: Data(), expectedContext: record.context)) {
            XCTAssertEqual($0 as? PasskeyBackupKeyWrapperError, .invalidInputLength)
        }
    }

    func testCanonicalOwnerCredentialAndEpochValidation() throws {
        for owner in ["google:subject", "owner:", "owner:" + base64URL(Data(repeating: 1, count: 31)),
                      "owner:" + base64URL(Data(repeating: 1, count: 32)) + "="] {
            XCTAssertThrowsError(try context(owner: owner))
        }
        for credential in ["", "invalid+base64", "YQ==", "YR", base64URL(Data(repeating: 1, count: 385))] {
            XCTAssertThrowsError(try context(credential: credential))
        }
        XCTAssertThrowsError(try context(epoch: -1))
        XCTAssertNoThrow(try context(epoch: 0))
        XCTAssertNoThrow(try context(credential: base64URL(Data(repeating: 1, count: 384)), epoch: Int64.max))
        // Swift grapheme count alone must not admit an unbounded combining-character context.
        XCTAssertThrowsError(try context(email: "a" + String(repeating: "\u{0301}", count: 3000) + "@example.com"))
    }

    func testProductionWrapUsesFreshSaltAndNonceAndCanBeOpened() throws {
        let context = try context()
        let firstSalt = try wrapper.newPrfSalt()
        let secondSalt = try wrapper.newPrfSalt()
        XCTAssertEqual(firstSalt.count, 32)
        XCTAssertNotEqual(firstSalt, secondSalt)
        let first = try wrapper.wrap(backupKey: backupKey, prfOutput: prfOutput, prfSalt: firstSalt, context: context)
        let second = try wrapper.wrap(backupKey: backupKey, prfOutput: prfOutput, prfSalt: firstSalt, context: context)
        XCTAssertNotEqual(first.hkdfSalt, second.hkdfSalt)
        XCTAssertNotEqual(first.nonce, second.nonce)
        XCTAssertNotEqual(first.ciphertextAndTag, second.ciphertextAndTag)
        XCTAssertEqual(try wrapper.unwrap(record: second, prfOutput: prfOutput, expectedContext: context), backupKey)
    }

    func testInjectedRandomnessHasExactLengthsAndFailureIsNotSubstituted() throws {
        var requested: [Int] = []
        let deterministic = PasskeyBackupCredentialKeyWrapper { count in
            requested.append(count)
            return Data(repeating: UInt8(requested.count), count: count)
        }
        _ = try deterministic.newPrfSalt()
        _ = try deterministic.wrap(backupKey: backupKey, prfOutput: prfOutput, prfSalt: prfSalt, context: context())
        XCTAssertEqual(requested, [32, 32, 12])
        let failed = PasskeyBackupCredentialKeyWrapper { _ in
            throw PasskeyBackupKeyWrapperError.randomGenerationFailed
        }
        XCTAssertThrowsError(try failed.newPrfSalt())
        XCTAssertThrowsError(
            try failed
                .wrap(backupKey: backupKey, prfOutput: prfOutput, prfSalt: prfSalt, context: context())
        )
        let short = PasskeyBackupCredentialKeyWrapper { _ in Data([1]) }
        XCTAssertThrowsError(try short.newPrfSalt())
        XCTAssertThrowsError(
            try short
                .wrap(backupKey: backupKey, prfOutput: prfOutput, prfSalt: prfSalt, context: context())
        )
        XCTAssertThrowsError(try PasskeyBackupCredentialKeyWrapper.secureRandomBytes(count: 0))
    }

    func testDescriptionsAreRedactedAndRecordContainsNoSecretFields() throws {
        let record = try fixedRecord()
        XCTAssertEqual(String(reflecting: record), "PasskeyBackupCredentialKeyWrapperRecord(<redacted>)")
        XCTAssertEqual(String(reflecting: record.context), "PasskeyBackupKeyWrapperContext(<redacted>)")
        XCTAssertEqual(
            Set(Mirror(reflecting: record).children.compactMap(\.label)),
            Set(["context", "prfSalt", "hkdfSalt", "nonce", "ciphertextAndTag"])
        )
        XCTAssertFalse(PasskeyBackupReleaseConfig.isPasskeyBackupEnabled)
    }

    private func context(
        owner: String = "owner:ERERERERERERERERERERERERERERERERERERERERERE",
        credential: String = "IiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI", epoch: Int64 = 7,
        storageKey: String = "wallet-1234", walletID: String = "wallet-001",
        email: String = "alice@example.com", createdAt: Int64 = 1_767_225_600_000
    ) throws -> PasskeyBackupKeyWrapperContext {
        try PasskeyBackupKeyWrapperContext(
            ownerSubject: owner, credentialId: credential, keyEpoch: epoch,
            envelopeMetadata: PasskeyBackupEnvelopeMetadata(
                storageKey: storageKey, walletId: walletID, accountName: email, createdAtMillis: createdAt
            )
        )
    }

    private func fixedRecord() throws -> PasskeyBackupCredentialKeyWrapperRecord {
        try wrapper.wrapWithParameters(
            backupKey: backupKey, prfOutput: prfOutput, prfSalt: prfSalt, hkdfSalt: hkdfSalt, nonce: nonce,
            context: context()
        )
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }
}
