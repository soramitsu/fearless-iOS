import Foundation

// MARK: - Protocol

public protocol RuntimeStorageEntryMetadata {
    var name: String { get }
    var modifier: RuntimeStorageEntryModifier { get }
    var type: StorageEntryType { get }
    var defaultValue: Data { get }
    var documentation: [String] { get }
}

// MARK: - V1

public extension RuntimeMetadataV1 {
    struct StorageEntryMetadata: RuntimeStorageEntryMetadata, ScaleCodable {
        public let name: String
        public let modifier: RuntimeStorageEntryModifier
        public let type: StorageEntryType
        public let defaultValue: Data
        public let documentation: [String]

        public init(
            name: String,
            modifier: RuntimeStorageEntryModifier,
            type: StorageEntryType,
            defaultValue: Data,
            documentation: [String]
        ) {
            self.name = name
            self.modifier = modifier
            self.type = type
            self.defaultValue = defaultValue
            self.documentation = documentation
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try name.encode(scaleEncoder: scaleEncoder)
            try modifier.encode(scaleEncoder: scaleEncoder)
            try type.encode(scaleEncoder: scaleEncoder)
            try defaultValue.encode(scaleEncoder: scaleEncoder)
            try documentation.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            name = try String(scaleDecoder: scaleDecoder)
            modifier = try RuntimeStorageEntryModifier(scaleDecoder: scaleDecoder)
            type = try StorageEntryType(scaleDecoder: scaleDecoder)
            defaultValue = try Data(scaleDecoder: scaleDecoder)
            documentation = try [String](scaleDecoder: scaleDecoder)
        }
    }
}

// MARK: - V14

public extension RuntimeMetadataV14 {
    struct StorageEntryMetadata: RuntimeStorageEntryMetadata, ScaleCodable {
        public let name: String
        public let modifier: RuntimeStorageEntryModifier
        public let type: StorageEntryType
        public let defaultValue: Data
        public let documentation: [String]

        public init(
            name: String,
            modifier: RuntimeStorageEntryModifier,
            type: StorageEntryType,
            defaultValue: Data,
            documentation: [String]
        ) {
            self.name = name
            self.modifier = modifier
            self.type = type
            self.defaultValue = defaultValue
            self.documentation = documentation
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try name.encode(scaleEncoder: scaleEncoder)
            try modifier.encode(scaleEncoder: scaleEncoder)
            try type.encode(scaleEncoder: scaleEncoder)
            try defaultValue.encode(scaleEncoder: scaleEncoder)
            try documentation.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            name = try String(scaleDecoder: scaleDecoder)
            modifier = try RuntimeStorageEntryModifier(scaleDecoder: scaleDecoder)
            type = try StorageEntryType(v14ScaleDecoder: scaleDecoder)
            defaultValue = try Data(scaleDecoder: scaleDecoder)
            documentation = try [String](scaleDecoder: scaleDecoder)
        }
    }
}
