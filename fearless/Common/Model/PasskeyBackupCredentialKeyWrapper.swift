import CryptoKit
import Foundation
import Security

enum PasskeyBackupKeyWrapperError: Error, Equatable {
    case invalidContext
    case invalidInputLength
    case contextMismatch
    case authenticationFailed
    case randomGenerationFailed
    case invalidRecord
}

/// Public authenticated context. A caller must obtain owner and epoch from the reviewed lifecycle authority.
struct PasskeyBackupKeyWrapperContext: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let ownerSubject: String
    let credentialId: String
    let keyEpoch: Int64
    let envelopeMetadata: PasskeyBackupEnvelopeMetadata

    init(
        ownerSubject: String,
        credentialId: String,
        keyEpoch: Int64,
        envelopeMetadata: PasskeyBackupEnvelopeMetadata
    ) throws {
        let strings = [PasskeyBackupContract.PASSKEY_RP_ID, ownerSubject, envelopeMetadata.storageKey,
                       envelopeMetadata.walletId, envelopeMetadata.accountName, credentialId]
        guard ownerSubject.hasPrefix("owner:"), ownerSubject.utf8.count == 49,
              let owner = try? PasskeyBackupContract.decodeBase64URL(String(ownerSubject.dropFirst(6))),
              owner.count == 32,
              credentialId.utf8.count <= 512,
              let credential = try? PasskeyBackupContract.decodeBase64URL(credentialId),
              (1 ... 384).contains(credential.count), keyEpoch >= 0,
              strings.allSatisfy({ $0.utf8.count <= 4096 }),
              57 + strings.reduce(0, { $0 + $1.utf8.count }) <= 4096 else {
            throw PasskeyBackupKeyWrapperError.invalidContext
        }
        self.ownerSubject = ownerSubject
        self.credentialId = credentialId
        self.keyEpoch = keyEpoch
        self.envelopeMetadata = envelopeMetadata
    }

    var description: String { "PasskeyBackupKeyWrapperContext(<redacted>)" }
    var debugDescription: String { description }

    /// Byte contract shared with Android. No locale, JSON serializer or host byte order participates.
    func canonicalBytes() -> Data {
        var data = Data("FPBKWRAP1".utf8)
        Self.append(UInt32(1), to: &data)
        for value in [PasskeyBackupContract.PASSKEY_RP_ID, ownerSubject, envelopeMetadata.storageKey,
                      envelopeMetadata.walletId, envelopeMetadata.accountName] {
            Self.append(value, to: &data)
        }
        Self.append(UInt64(envelopeMetadata.createdAtMillis), to: &data)
        Self.append(UInt32(envelopeMetadata.schemaVersion), to: &data)
        Self.append(credentialId, to: &data)
        Self.append(UInt64(keyEpoch), to: &data)
        return data
    }

    private static func append(_ value: String, to data: inout Data) {
        let bytes = Data(value.utf8)
        append(UInt32(bytes.count), to: &data)
        data.append(bytes)
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }
}

/// Contains ciphertext and public metadata only. PRF output and plaintext key are never retained or serialized.
struct PasskeyBackupCredentialKeyWrapperRecord: CustomStringConvertible, CustomDebugStringConvertible {
    let context: PasskeyBackupKeyWrapperContext
    let prfSalt: Data
    let hkdfSalt: Data
    let nonce: Data
    let ciphertextAndTag: Data

    init(
        context: PasskeyBackupKeyWrapperContext,
        prfSalt: Data,
        hkdfSalt: Data,
        nonce: Data,
        ciphertextAndTag: Data
    ) throws {
        guard prfSalt.count == 32, hkdfSalt.count == 32, nonce.count == 12, ciphertextAndTag.count == 48 else {
            throw PasskeyBackupKeyWrapperError.invalidInputLength
        }
        self.context = context
        self.prfSalt = prfSalt
        self.hkdfSalt = hkdfSalt
        self.nonce = nonce
        self.ciphertextAndTag = ciphertextAndTag
    }

    var description: String { "PasskeyBackupCredentialKeyWrapperRecord(<redacted>)" }
    var debugDescription: String { description }
}

/// Pure local primitive. Native PRF verification, owner enrollment and rollback protection are separate gates.
final class PasskeyBackupCredentialKeyWrapper {
    private let randomBytes: (Int) throws -> Data

    init(randomBytes: @escaping (Int) throws -> Data = PasskeyBackupCredentialKeyWrapper.secureRandomBytes) {
        self.randomBytes = randomBytes
    }

    func newPrfSalt() throws -> Data {
        let salt = try randomBytes(32)
        guard salt.count == 32 else { throw PasskeyBackupKeyWrapperError.invalidInputLength }
        return salt
    }

    /// Opaque canonical record; no PRF output or plaintext backup key is serialized.
    func encodeRecord(_ record: PasskeyBackupCredentialKeyWrapperRecord) -> Data {
        let context = record.context.canonicalBytes()
        return Self.recordHeader(contextLength: context.count) + context + record.prfSalt + record.hkdfSalt +
            record.nonce + record.ciphertextAndTag
    }

    /// A verified owner/credential/backup manifest must supply expectedContext, never the untrusted record.
    func decodeRecord(
        _ encoded: Data, expectedContext: PasskeyBackupKeyWrapperContext
    ) throws -> PasskeyBackupCredentialKeyWrapperRecord {
        let expected = expectedContext.canonicalBytes()
        guard encoded.count == 140 + expected.count,
              encoded.prefix(16) == Self.recordHeader(contextLength: expected.count) else {
            throw PasskeyBackupKeyWrapperError.invalidRecord
        }
        guard encoded.dropFirst(16).prefix(expected.count) == expected else {
            throw PasskeyBackupKeyWrapperError.contextMismatch
        }
        let payload = encoded.dropFirst(16 + expected.count)
        return try PasskeyBackupCredentialKeyWrapperRecord(
            context: expectedContext, prfSalt: Data(payload.prefix(32)),
            hkdfSalt: Data(payload.dropFirst(32).prefix(32)),
            nonce: Data(payload.dropFirst(64).prefix(12)), ciphertextAndTag: Data(payload.suffix(48))
        )
    }

    func wrap(
        backupKey: Data,
        prfOutput: Data,
        prfSalt: Data,
        context: PasskeyBackupKeyWrapperContext
    ) throws -> PasskeyBackupCredentialKeyWrapperRecord {
        try wrapWithParameters(
            backupKey: backupKey, prfOutput: prfOutput, prfSalt: prfSalt,
            hkdfSalt: randomBytes(32), nonce: randomBytes(12), context: context
        )
    }

    // Explicit randomness is for fixed cross-platform vectors; production callers use wrap instead.
    // swiftlint:disable:next function_parameter_count
    func wrapWithParameters(
        backupKey: Data,
        prfOutput: Data,
        prfSalt: Data,
        hkdfSalt: Data,
        nonce: Data,
        context: PasskeyBackupKeyWrapperContext
    ) throws -> PasskeyBackupCredentialKeyWrapperRecord {
        guard backupKey.count == 32, nonce.count == 12 else { throw PasskeyBackupKeyWrapperError.invalidInputLength }
        let key = try deriveKey(prfOutput: prfOutput, prfSalt: prfSalt, hkdfSalt: hkdfSalt, context: context)
        let box = try AES.GCM.seal(
            backupKey, using: key, nonce: AES.GCM.Nonce(data: nonce),
            authenticating: Self.additionalAuthenticatedData(context: context, prfSalt: prfSalt, hkdfSalt: hkdfSalt)
        )
        return try PasskeyBackupCredentialKeyWrapperRecord(
            context: context, prfSalt: prfSalt, hkdfSalt: hkdfSalt, nonce: nonce,
            ciphertextAndTag: box.ciphertext + box.tag
        )
    }

    func unwrap(
        record: PasskeyBackupCredentialKeyWrapperRecord,
        prfOutput: Data,
        expectedContext: PasskeyBackupKeyWrapperContext
    ) throws -> Data {
        guard record.context == expectedContext else { throw PasskeyBackupKeyWrapperError.contextMismatch }
        let key = try deriveKey(
            prfOutput: prfOutput, prfSalt: record.prfSalt, hkdfSalt: record.hkdfSalt, context: expectedContext
        )
        do {
            let box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: record.nonce), ciphertext: record.ciphertextAndTag.prefix(32),
                tag: record.ciphertextAndTag.suffix(16)
            )
            let result = try AES.GCM.open(
                box, using: key,
                authenticating: Self.additionalAuthenticatedData(
                    context: expectedContext, prfSalt: record.prfSalt, hkdfSalt: record.hkdfSalt
                )
            )
            guard result.count == 32 else { throw PasskeyBackupKeyWrapperError.invalidInputLength }
            return result
        } catch {
            throw PasskeyBackupKeyWrapperError.authenticationFailed
        }
    }

    func deriveKey(
        prfOutput: Data, prfSalt: Data, hkdfSalt: Data, context: PasskeyBackupKeyWrapperContext
    ) throws -> SymmetricKey {
        guard prfOutput.count == 32, prfSalt.count == 32, hkdfSalt.count == 32 else {
            throw PasskeyBackupKeyWrapperError.invalidInputLength
        }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: prfOutput), salt: hkdfSalt,
            info: Data("FPBK-PRF-KEK-v1".utf8) + context.canonicalBytes() + prfSalt, outputByteCount: 32
        )
    }

    static func additionalAuthenticatedData(
        context: PasskeyBackupKeyWrapperContext, prfSalt: Data, hkdfSalt: Data
    ) -> Data {
        Data("FPBK-WRAP-AAD-v1".utf8) + context.canonicalBytes() + prfSalt + hkdfSalt
    }

    static func secureRandomBytes(count: Int) throws -> Data {
        guard count == 12 || count == 32 else { throw PasskeyBackupKeyWrapperError.invalidInputLength }
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, address)
        }
        guard status == errSecSuccess else { throw PasskeyBackupKeyWrapperError.randomGenerationFailed }
        return bytes
    }

    private static func recordHeader(contextLength: Int) -> Data {
        var header = Data("FPBKWRP1".utf8)
        for value in [UInt32(1), UInt32(contextLength)] {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { header.append(contentsOf: $0) }
        }
        return header
    }
}
