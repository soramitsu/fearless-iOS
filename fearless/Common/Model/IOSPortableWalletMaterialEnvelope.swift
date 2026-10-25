import Foundation

/// Shared Android/iOS plaintext envelope grammar. Local drafts remain opaque; a separate
/// portable semantic payload may use the portable source/mode pair, but decoding this header
/// alone never proves the material installable on another platform. No recovery flow uses it yet.
///
/// Bytes: ASCII "FPWMLE01", u8 version (1), u8 origin, u8 source format, u8 derivation mode,
/// big-endian u32 payload length, then exact payload bytes. The Android codec is byte-identical.
enum IOSPortableWalletMaterialEnvelope {
    enum Origin: UInt8 {
        case android = 1
        case ios = 2
    }

    enum SourceFormat: UInt8 {
        case androidDraftV2 = 1
        /// Reserved for the existing iOS in-memory draft; no serializer or installer is wired.
        case iosKeychainV2Inventory = 2
        case portableSemanticV1 = 3
    }

    enum DerivationMode: UInt8 {
        case localOpaque = 0
        case portable = 1
    }

    enum CodecError: Error, Equatable {
        case unsupportedSource
        case invalidSize
        case invalidLength
        case unsupportedVersion
    }

    struct Record: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let origin: Origin
        let sourceFormat: SourceFormat
        let derivationMode: DerivationMode
        let payload: Data

        var description: String { "IOSPortableWalletMaterialEnvelope.Record(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    private static let magic: [UInt8] = Array("FPWMLE01".utf8)
    private static let version: UInt8 = 1
    private static let headerSize = 16
    private static let maxEncodedBytes = 256 * 1024 - 44 // FPBKAEAD v1 plaintext ceiling.
    private static let maxPayloadBytes = maxEncodedBytes - headerSize

    static func encode(_ record: Record) throws -> Data {
        try validateSource(record)
        guard (1 ... maxPayloadBytes).contains(record.payload.count) else {
            throw CodecError.invalidSize
        }
        let size = record.payload.count
        var encoded = Data(capacity: headerSize + size)
        encoded.append(contentsOf: magic)
        encoded.append(version)
        encoded.append(record.origin.rawValue)
        encoded.append(record.sourceFormat.rawValue)
        encoded.append(record.derivationMode.rawValue)
        encoded.append(UInt8((size >> 24) & 0xFF))
        encoded.append(UInt8((size >> 16) & 0xFF))
        encoded.append(UInt8((size >> 8) & 0xFF))
        encoded.append(UInt8(size & 0xFF))
        encoded.append(record.payload)
        return encoded
    }

    static func decode(_ encoded: Data) throws -> Record {
        guard ((headerSize + 1) ... maxEncodedBytes).contains(encoded.count) else {
            throw CodecError.invalidSize
        }
        let header = Array(encoded.prefix(headerSize))
        guard Array(header.prefix(magic.count)) == magic, header[8] == version else {
            throw CodecError.unsupportedVersion
        }
        guard let origin = Origin(rawValue: header[9]),
              let source = SourceFormat(rawValue: header[10]),
              let mode = DerivationMode(rawValue: header[11]) else {
            throw CodecError.unsupportedSource
        }
        let length = Int(header[12]) << 24 | Int(header[13]) << 16 |
            Int(header[14]) << 8 | Int(header[15])
        guard (1 ... maxPayloadBytes).contains(length), length == encoded.count - headerSize else {
            throw CodecError.invalidLength
        }
        let record = Record(
            origin: origin, sourceFormat: source, derivationMode: mode,
            payload: Data(encoded.dropFirst(headerSize))
        )
        try validateSource(record)
        return record
    }

    private static func validateSource(_ record: Record) throws {
        let supported: Bool
        switch (record.sourceFormat, record.derivationMode) {
        case (.androidDraftV2, .localOpaque):
            supported = record.origin == .android
        case (.iosKeychainV2Inventory, .localOpaque):
            supported = record.origin == .ios
        case (.portableSemanticV1, .portable):
            supported = true
        default:
            supported = false
        }
        guard supported else {
            throw CodecError.unsupportedSource
        }
    }
}
