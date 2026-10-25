import Foundation

// MARK: - Protocol

public protocol RuntimeEventMetadata {
    var name: String { get }
    /// Index of the event inside its pallet as the runtime declares it: the variant index in V14.
    /// `nil` for metadata that carries no index, where the position in the list is the index.
    var eventIndex: UInt8? { get }
    var arguments: [String] { get }
    var documentation: [String] { get }
}

public extension RuntimeEventMetadata {
    var eventIndex: UInt8? { nil }
}

// MARK: - V1

public extension RuntimeMetadataV1 {
    struct EventMetadata: RuntimeEventMetadata {
        public let name: String
        public let arguments: [String]
        public let documentation: [String]

        public init(name: String, arguments: [String], documentation: [String]) {
            self.name = name
            self.arguments = arguments
            self.documentation = documentation
        }
    }
}

extension RuntimeMetadataV1.EventMetadata: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try name.encode(scaleEncoder: scaleEncoder)
        try arguments.encode(scaleEncoder: scaleEncoder)
        try documentation.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        name = try String(scaleDecoder: scaleDecoder)
        arguments = try [String](scaleDecoder: scaleDecoder)
        documentation = try [String](scaleDecoder: scaleDecoder)
    }
}

// MARK: - V14

public extension RuntimeMetadataV14 {
    struct EventMetadata: RuntimeEventMetadata {
        public let name: String
        public let eventIndex: UInt8?
        public let arguments: [String]
        public let documentation: [String]

        public init(item: TypeMetadata.Def.Variant.Item, schemaResolver: Schema.Resolver) throws {
            name = item.name
            eventIndex = item.index
            arguments = try item.fields.map { try schemaResolver.typeName(for: $0.type) }
            documentation = item.docs
        }
    }
}
