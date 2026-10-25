import Foundation

// MARK: - Protocol

public protocol RuntimeStorageMetadata: ScaleCodable {
    var prefix: String { get }
    var entries: [RuntimeStorageEntryMetadata] { get }
}

// MARK: - V1

public extension RuntimeMetadataV1 {
    struct StorageMetadata: RuntimeStorageMetadata, ScaleCodable {
        public let prefix: String
        private let _entries: [StorageEntryMetadata]
        public var entries: [RuntimeStorageEntryMetadata] { _entries }

        public init(prefix: String, entries: [StorageEntryMetadata]) {
            self.prefix = prefix
            _entries = entries
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try prefix.encode(scaleEncoder: scaleEncoder)
            try _entries.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            prefix = try String(scaleDecoder: scaleDecoder)
            _entries = try [StorageEntryMetadata](scaleDecoder: scaleDecoder)
        }
    }
}

// MARK: - V14

public extension RuntimeMetadataV14 {
    struct StorageMetadata: RuntimeStorageMetadata, ScaleCodable {
        public let prefix: String
        private let _entries: [StorageEntryMetadata]
        public var entries: [RuntimeStorageEntryMetadata] { _entries }

        public init(prefix: String, entries: [StorageEntryMetadata]) {
            self.prefix = prefix
            _entries = entries
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try prefix.encode(scaleEncoder: scaleEncoder)
            try _entries.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            prefix = try String(scaleDecoder: scaleDecoder)
            _entries = try [StorageEntryMetadata](scaleDecoder: scaleDecoder)
        }
    }
}
