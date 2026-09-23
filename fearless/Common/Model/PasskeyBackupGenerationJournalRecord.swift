import CryptoKit
import Foundation

enum PasskeyBackupGenerationJournalError: Error, Equatable {
    case invalidOperation
    case invalidRecord
    case scopeMismatch
    case capacityExceeded
    case unavailable
}

/// Supplied by authenticated owner state and the selected verified Google account, never by a journal file.
struct PasskeyBackupGenerationJournalScope {
    let ownerSubject: String
    let backupNamespace: String
    let storageAccountBinding: String

    func matches(_ context: PasskeyBackupGenerationV1.Context) -> Bool {
        ownerSubject == context.ownerSubject && backupNamespace == context.backupNamespace &&
            storageAccountBinding == context.storageAccountBinding
    }
}

struct PasskeyBackupGenerationJournalEntry: CustomStringConvertible, CustomDebugStringConvertible {
    let operationID: String
    let fileID: String
    let context: PasskeyBackupGenerationV1.Context
    let bytes: Data
    let sha256: String
    let createAttempted: Bool

    var description: String { "PasskeyBackupGenerationJournalEntry(<redacted>)" }
    var debugDescription: String { description }
}

/// A closed, checksummed local record. It contains ciphertext and opaque wrappers, never plaintext or PRF output.
enum PasskeyBackupGenerationJournalRecord {
    static let maximumBytes = PasskeyBackupGenerationV1Format.maximumBytes + 8192
    private static let magic = Data("FPBKJRN1".utf8)

    static func requireOperationID(_ value: String) throws {
        guard value.utf8.count == 43,
              let decoded = try? PasskeyBackupContract.decodeBase64URL(value), decoded.count == 32 else {
            throw PasskeyBackupGenerationJournalError.invalidOperation
        }
    }

    static func encode(_ entry: PasskeyBackupGenerationJournalEntry) throws -> Data {
        try requireOperationID(entry.operationID)
        try GoogleDriveGenerationResponse.requireFileID(entry.fileID)
        guard entry.sha256 == PasskeyBackupGenerationV1Format.sha256(entry.bytes),
              entry.bytes.count <= PasskeyBackupGenerationV1Format.maximumBytes else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        let generation = try PasskeyBackupGenerationV1Format.decode(
            entry.bytes, expectedContext: entry.context, expectedSha256: entry.sha256
        )
        guard try PasskeyBackupGenerationV1Format.encode(generation) == entry.bytes else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        var data = magic
        append(UInt32(1), to: &data)
        try appendText(entry.operationID, to: &data)
        try appendText(entry.fileID, to: &data)
        try appendText(entry.context.ownerSubject, to: &data)
        try appendText(entry.context.backupNamespace, to: &data)
        try appendText(entry.context.generationId, to: &data)
        append(UInt64(entry.context.parentHeadRevision), to: &data)
        data.append(entry.context.parentHeadSha256 == nil ? 0 : 1)
        if let parent = entry.context.parentHeadSha256 { try data.append(digestBytes(parent)) }
        append(UInt64(entry.context.keyEpoch), to: &data)
        try data.append(digestBytes(entry.context.storageAccountBinding))
        try data.append(digestBytes(entry.sha256))
        try appendBytes(entry.bytes, maximum: PasskeyBackupGenerationV1Format.maximumBytes, to: &data)
        data.append(contentsOf: SHA256.hash(data: data))
        guard data.count <= maximumBytes else { throw PasskeyBackupGenerationJournalError.invalidRecord }
        return data
    }

    static func decode(_ bytes: Data, attempted: Bool) throws -> PasskeyBackupGenerationJournalEntry {
        guard (32 ... maximumBytes).contains(bytes.count) else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        let content = Data(bytes.dropLast(32))
        guard Data(SHA256.hash(data: content)) == bytes.suffix(32) else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        var reader = Reader(content)
        guard try reader.take(8) == magic, try reader.uint32() == 1 else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        let operationID = try reader.text(maximum: 43)
        try requireOperationID(operationID)
        let fileID = try reader.text(maximum: 256)
        try GoogleDriveGenerationResponse.requireFileID(fileID)
        let owner = try reader.text(maximum: 64)
        let namespace = try reader.text(maximum: 64)
        let generationID = try reader.text(maximum: 43)
        let revision = try reader.int64()
        let marker = try reader.take(1)[0]
        guard marker <= 1 else { throw PasskeyBackupGenerationJournalError.invalidRecord }
        let parent = try marker == 1 ? hex(reader.take(32)) : nil
        let context = try PasskeyBackupGenerationV1.Context(
            ownerSubject: owner, backupNamespace: namespace, generationId: generationID,
            parentHeadRevision: revision, parentHeadSha256: parent,
            keyEpoch: reader.int64(), storageAccountBinding: hex(reader.take(32))
        )
        let sha256 = try hex(reader.take(32))
        let bundle = try reader.bytes(maximum: PasskeyBackupGenerationV1Format.maximumBytes)
        guard reader.remaining == 0, PasskeyBackupGenerationV1Format.sha256(bundle) == sha256 else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        let generation = try PasskeyBackupGenerationV1Format.decode(
            bundle, expectedContext: context, expectedSha256: sha256
        )
        guard try PasskeyBackupGenerationV1Format.encode(generation) == bundle else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        let entry = PasskeyBackupGenerationJournalEntry(
            operationID: operationID, fileID: fileID, context: context,
            bytes: bundle, sha256: sha256, createAttempted: attempted
        )
        guard try encode(entry) == bytes else { throw PasskeyBackupGenerationJournalError.invalidRecord }
        return entry
    }

    static func attemptMarker(for record: Data) -> Data {
        Data("FPBKATT1".utf8) + Data(SHA256.hash(data: record))
    }

    private static func appendText(_ value: String, to data: inout Data) throws {
        try appendBytes(Data(value.utf8), maximum: 256, to: &data)
    }

    private static func appendBytes(_ bytes: Data, maximum: Int, to data: inout Data) throws {
        guard (1 ... maximum).contains(bytes.count) else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        append(UInt32(bytes.count), to: &data)
        data.append(bytes)
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    private static func digestBytes(_ value: String) throws -> Data {
        guard value.utf8.count == 64,
              value.utf8.allSatisfy({ (48 ... 57).contains($0) || (97 ... 102).contains($0) }) else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        var result = Data()
        for offset in stride(from: 0, to: 64, by: 2) {
            let start = value.index(value.startIndex, offsetBy: offset)
            let end = value.index(start, offsetBy: 2)
            guard let byte = UInt8(value[start ..< end], radix: 16) else {
                throw PasskeyBackupGenerationJournalError.invalidRecord
            }
            result.append(byte)
        }
        return result
    }

    private static func hex(_ bytes: Data) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private struct Reader {
        private let content: Data
        private var offset = 0
        var remaining: Int { content.count - offset }

        init(_ content: Data) { self.content = content }

        mutating func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= remaining else { throw PasskeyBackupGenerationJournalError.invalidRecord }
            defer { offset += count }
            return content.subdata(in: offset ..< offset + count)
        }

        mutating func uint32() throws -> UInt32 {
            try take(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }

        mutating func int64() throws -> Int64 {
            let value = try take(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            guard value <= UInt64(Int64.max) else { throw PasskeyBackupGenerationJournalError.invalidRecord }
            return Int64(value)
        }

        mutating func bytes(maximum: Int) throws -> Data {
            let count = try uint32()
            guard count > 0, Int(count) <= maximum, Int(count) <= remaining else {
                throw PasskeyBackupGenerationJournalError.invalidRecord
            }
            return try take(Int(count))
        }

        mutating func text(maximum: Int) throws -> String {
            guard let value = try String(data: bytes(maximum: maximum), encoding: .utf8) else {
                throw PasskeyBackupGenerationJournalError.invalidRecord
            }
            return value
        }
    }
}
