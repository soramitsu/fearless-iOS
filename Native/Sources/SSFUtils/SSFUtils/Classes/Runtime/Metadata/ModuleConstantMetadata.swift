import BigInt
import Foundation

// MARK: - Protocol

public protocol RuntimeModuleConstantMetadata {
    var name: String { get }
    func type(using schemaResolver: Schema.Resolver) throws -> String
    var value: Data { get }
    var documentation: [String] { get }
}

// MARK: - V1

public extension RuntimeMetadataV1 {
    struct ModuleConstantMetadata: RuntimeModuleConstantMetadata {
        public let name: String
        public let type: String
        public let value: Data
        public let documentation: [String]

        public init(name: String, type: String, value: Data, documentation: [String]) {
            self.name = name
            self.type = type
            self.value = value
            self.documentation = documentation
        }

        public func type(using _: Schema.Resolver) throws -> String {
            type
        }
    }
}

extension RuntimeMetadataV1.ModuleConstantMetadata: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try name.encode(scaleEncoder: scaleEncoder)
        try type.encode(scaleEncoder: scaleEncoder)
        try value.encode(scaleEncoder: scaleEncoder)
        try documentation.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        name = try String(scaleDecoder: scaleDecoder)
        type = try String(scaleDecoder: scaleDecoder)
        value = try Data(scaleDecoder: scaleDecoder)
        documentation = try [String](scaleDecoder: scaleDecoder)
    }
}

// MARK: - V14

public extension RuntimeMetadataV14 {
    struct ModuleConstantMetadata: RuntimeModuleConstantMetadata {
        public let name: String
        private let typeIndex: BigUInt
        public let value: Data
        public let documentation: [String]

        public init(name: String, typeIndex: BigUInt, value: Data, documentation: [String]) {
            self.name = name
            self.typeIndex = typeIndex
            self.value = value
            self.documentation = documentation
        }

        public func type(using schemaResolver: Schema.Resolver) throws -> String {
            try schemaResolver.typeName(for: typeIndex)
        }
    }
}

extension RuntimeMetadataV14.ModuleConstantMetadata: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try name.encode(scaleEncoder: scaleEncoder)
        try typeIndex.encode(scaleEncoder: scaleEncoder)
        try value.encode(scaleEncoder: scaleEncoder)
        try documentation.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        name = try String(scaleDecoder: scaleDecoder)
        typeIndex = try BigUInt(scaleDecoder: scaleDecoder)
        value = try Data(scaleDecoder: scaleDecoder)
        documentation = try [String](scaleDecoder: scaleDecoder)
    }
}
