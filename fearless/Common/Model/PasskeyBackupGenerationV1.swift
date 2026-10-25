import CryptoKit
import Foundation

enum PasskeyBackupGenerationError: Error, Equatable {
    case invalidContext
    case invalidFormat
    case contextMismatch
    case digestMismatch
}

/// An immutable encrypted candidate. Neither decoding nor a matching digest proves that the backup can be opened.
struct PasskeyBackupGenerationV1: CustomStringConvertible, CustomDebugStringConvertible {
    struct Context: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let ownerSubject: String
        let backupNamespace: String
        let generationId: String
        let parentHeadRevision: Int64
        let parentHeadSha256: String?
        let keyEpoch: Int64
        let storageAccountBinding: String

        init(
            ownerSubject: String, backupNamespace: String, generationId: String,
            parentHeadRevision: Int64, parentHeadSha256: String?, keyEpoch: Int64,
            storageAccountBinding: String
        ) throws {
            guard Self.identifier(ownerSubject, prefix: "owner:"),
                  Self.identifier(backupNamespace, prefix: "backup:"),
                  Self.identifier(generationId, prefix: ""),
                  parentHeadRevision >= 0, keyEpoch >= 1,
                  (parentHeadRevision == 0) == (parentHeadSha256 == nil),
                  parentHeadSha256.map(Self.isDigest) ?? true,
                  Self.isDigest(storageAccountBinding) else {
                throw PasskeyBackupGenerationError.invalidContext
            }
            self.ownerSubject = ownerSubject
            self.backupNamespace = backupNamespace
            self.generationId = generationId
            self.parentHeadRevision = parentHeadRevision
            self.parentHeadSha256 = parentHeadSha256
            self.keyEpoch = keyEpoch
            self.storageAccountBinding = storageAccountBinding
        }

        var description: String { "PasskeyBackupGenerationV1.Context(<redacted>)" }
        var debugDescription: String { description }

        private static func identifier(_ value: String, prefix: String) -> Bool {
            guard value.hasPrefix(prefix) else { return false }
            let token = String(value.dropFirst(prefix.count))
            guard token.utf8.count == 43,
                  let decoded = try? PasskeyBackupContract.decodeBase64URL(token), decoded.count == 32 else {
                return false
            }
            return true
        }

        fileprivate static func isDigest(_ value: String) -> Bool {
            value.utf8.count == 64 && value.utf8.allSatisfy { (48 ... 57).contains($0) || (97 ... 102).contains($0) }
        }
    }

    let context: Context
    let envelope: PasskeyBackupEncryptedRecord
    let wrappers: [PasskeyBackupCredentialKeyWrapperRecord]

    init(
        context: Context, envelope: PasskeyBackupEncryptedRecord,
        wrappers: [PasskeyBackupCredentialKeyWrapperRecord]
    ) throws {
        guard (1 ... 32).contains(wrappers.count) else { throw PasskeyBackupGenerationError.invalidFormat }
        let metadata = try envelope.envelopeMetadata()
        let sorted = wrappers.sorted { $0.context.credentialId < $1.context.credentialId }
        guard Set(sorted.map { $0.context.credentialId }).count == sorted.count,
              sorted.allSatisfy({ $0.context.ownerSubject == context.ownerSubject &&
                      $0.context.keyEpoch == context.keyEpoch && $0.context.envelopeMetadata == metadata }) else {
            throw PasskeyBackupGenerationError.contextMismatch
        }
        self.context = context
        self.envelope = envelope
        self.wrappers = sorted
    }

    var description: String { "PasskeyBackupGenerationV1(<redacted>)" }
    var debugDescription: String { description }
}

/// FPBKGEN1 is shared with Android. Expected context and SHA-256 must come from an authenticated head or durable journal.
enum PasskeyBackupGenerationV1Format {
    static let maximumBytes = 512 * 1024
    private static let maximumTextBytes = 2048
    private static let maximumWrapperBytes = 8192
    private static let magic = Data("FPBKGEN1".utf8)

    static func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    static func storageAccountBinding(verifiedGoogleSubject: String) throws -> String {
        guard (1 ... 255).contains(verifiedGoogleSubject.utf8.count),
              verifiedGoogleSubject.utf8.allSatisfy({ (48 ... 57).contains($0) ||
                      (65 ... 90).contains($0) || (97 ... 122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw PasskeyBackupGenerationError.invalidContext
        }
        return sha256(Data("FPBK-GOOGLE-SUB-v1\0".utf8) + Data(verifiedGoogleSubject.utf8))
    }

    static func encode(_ generation: PasskeyBackupGenerationV1) throws -> Data {
        var data = magic
        append(UInt32(1), to: &data)
        let context = generation.context
        try appendText(context.ownerSubject, to: &data)
        try appendText(context.backupNamespace, to: &data)
        try appendText(context.generationId, to: &data)
        append(UInt64(context.parentHeadRevision), to: &data)
        data.append(context.parentHeadSha256 == nil ? 0 : 1)
        if let digest = context.parentHeadSha256 { data.append(try digestBytes(digest)) }
        append(UInt64(context.keyEpoch), to: &data)
        data.append(try digestBytes(context.storageAccountBinding))
        let envelope = generation.envelope
        try appendText(envelope.storageKey, to: &data)
        try appendText(envelope.walletId, to: &data)
        try appendText(envelope.accountName, to: &data)
        append(UInt64(envelope.createdAtMillis), to: &data)
        append(UInt32(envelope.schemaVersion), to: &data)
        try appendBytes(envelope.encryptedPayload, maximum: maximumBytes, to: &data)
        append(UInt32(generation.wrappers.count), to: &data)
        let codec = PasskeyBackupCredentialKeyWrapper()
        for record in generation.wrappers {
            try appendText(record.context.credentialId, to: &data)
            try appendBytes(codec.encodeRecord(record), maximum: maximumWrapperBytes, to: &data)
        }
        guard data.count <= maximumBytes else { throw PasskeyBackupGenerationError.invalidFormat }
        return data
    }

    static func decode(
        _ bytes: Data, expectedContext: PasskeyBackupGenerationV1.Context,
        expectedSha256: String
    ) throws -> PasskeyBackupGenerationV1 {
        guard (1 ... maximumBytes).contains(bytes.count),
              PasskeyBackupGenerationV1.Context.isDigest(expectedSha256) else {
            throw PasskeyBackupGenerationError.invalidFormat
        }
        guard sha256(bytes) == expectedSha256 else { throw PasskeyBackupGenerationError.digestMismatch }
        var reader = Reader(bytes)
        guard try reader.take(magic.count) == magic, try reader.uint32() == 1 else {
            throw PasskeyBackupGenerationError.invalidFormat
        }
        let owner = try reader.text()
        let namespace = try reader.text()
        let generationId = try reader.text()
        let revision = try reader.int64()
        let marker = try reader.take(1)[0]
        guard marker <= 1 else { throw PasskeyBackupGenerationError.invalidFormat }
        let parent = marker == 1 ? try hex(reader.take(32)) : nil
        let context = try PasskeyBackupGenerationV1.Context(
            ownerSubject: owner, backupNamespace: namespace, generationId: generationId,
            parentHeadRevision: revision, parentHeadSha256: parent,
            keyEpoch: reader.int64(), storageAccountBinding: hex(reader.take(32))
        )
        guard context == expectedContext else { throw PasskeyBackupGenerationError.contextMismatch }
        let storageKey = try reader.text()
        let walletId = try reader.text()
        let accountName = try reader.text()
        let created = try reader.int64()
        let schema = try reader.uint32()
        let encrypted = try reader.bytes(maximum: maximumBytes)
        let envelope = try PasskeyBackupEncryptedRecord(
            storageKey: storageKey, walletId: walletId, accountName: accountName,
            createdAtMillis: created, encryptedPayload: encrypted, schemaVersion: Int(schema)
        )
        let count = try reader.uint32()
        guard (1 ... 32).contains(Int(count)) else { throw PasskeyBackupGenerationError.invalidFormat }
        let codec = PasskeyBackupCredentialKeyWrapper()
        let metadata = try envelope.envelopeMetadata()
        var wrappers: [PasskeyBackupCredentialKeyWrapperRecord] = []
        var previousId: String?
        for _ in 0 ..< Int(count) {
            let credentialId = try reader.text()
            if let previousId = previousId, credentialId <= previousId {
                throw PasskeyBackupGenerationError.invalidFormat
            }
            previousId = credentialId
            let expected = try PasskeyBackupKeyWrapperContext(
                ownerSubject: context.ownerSubject, credentialId: credentialId,
                keyEpoch: context.keyEpoch, envelopeMetadata: metadata
            )
            wrappers.append(try codec.decodeRecord(reader.bytes(maximum: maximumWrapperBytes), expectedContext: expected))
        }
        guard reader.remaining == 0 else { throw PasskeyBackupGenerationError.invalidFormat }
        let generation = try PasskeyBackupGenerationV1(context: context, envelope: envelope, wrappers: wrappers)
        guard try encode(generation) == bytes else { throw PasskeyBackupGenerationError.invalidFormat }
        return generation
    }

    private static func appendText(_ value: String, to data: inout Data) throws {
        try appendBytes(Data(value.utf8), maximum: maximumTextBytes, to: &data)
    }

    private static func appendBytes(_ bytes: Data, maximum: Int, to data: inout Data) throws {
        guard (1 ... maximum).contains(bytes.count) else { throw PasskeyBackupGenerationError.invalidFormat }
        append(UInt32(bytes.count), to: &data)
        data.append(bytes)
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    private static func digestBytes(_ digest: String) throws -> Data {
        guard PasskeyBackupGenerationV1.Context.isDigest(digest) else {
            throw PasskeyBackupGenerationError.invalidFormat
        }
        var bytes = Data()
        for index in stride(from: 0, to: digest.utf8.count, by: 2) {
            let start = digest.index(digest.startIndex, offsetBy: index)
            let end = digest.index(start, offsetBy: 2)
            guard let byte = UInt8(digest[start ..< end], radix: 16) else {
                throw PasskeyBackupGenerationError.invalidFormat
            }
            bytes.append(byte)
        }
        return bytes
    }

    private static func hex(_ bytes: Data) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private struct Reader {
        private let bytes: Data
        private var offset = 0
        var remaining: Int { bytes.count - offset }

        init(_ bytes: Data) { self.bytes = bytes }

        mutating func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= remaining else { throw PasskeyBackupGenerationError.invalidFormat }
            defer { offset += count }
            return bytes.subdata(in: offset ..< offset + count)
        }

        mutating func uint32() throws -> UInt32 {
            try take(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }

        mutating func int64() throws -> Int64 {
            let value = try take(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            guard value <= UInt64(Int64.max) else { throw PasskeyBackupGenerationError.invalidFormat }
            return Int64(value)
        }

        mutating func bytes(maximum: Int) throws -> Data {
            let count = try uint32()
            guard count > 0, Int(count) <= maximum, Int(count) <= remaining else {
                throw PasskeyBackupGenerationError.invalidFormat
            }
            return try take(Int(count))
        }

        mutating func text() throws -> String {
            let value = try bytes(maximum: maximumTextBytes)
            guard let decoded = String(data: value, encoding: .utf8) else {
                throw PasskeyBackupGenerationError.invalidFormat
            }
            return decoded
        }
    }
}
