import BigInt
import Foundation

// MARK: - Protocol

public protocol RuntimeFunctionMetadata {
    var name: String { get }
    /// Index of the call inside its pallet, exactly as the runtime declares it.
    ///
    /// V14 metadata carries it as the variant index of the pallet's call enum, and those indexes
    /// have gaps (`Balances.transfer_keep_alive` is 3 while it is the third entry of the list).
    /// `nil` for metadata versions that carry no index; there the position in the pallet's call
    /// list is the index.
    var callIndex: UInt8? { get }
    var arguments: [RuntimeFunctionArgumentMetadata] { get }
    var documentation: [String] { get }
}

public extension RuntimeFunctionMetadata {
    var callIndex: UInt8? { nil }
}

// MARK: - V1

public extension RuntimeMetadataV1 {
    struct FunctionMetadata: RuntimeFunctionMetadata, ScaleCodable {
        public let name: String
        private let _arguments: [FunctionArgumentMetadata]
        public var arguments: [RuntimeFunctionArgumentMetadata] { _arguments }
        public let documentation: [String]

        public init(name: String, arguments: [FunctionArgumentMetadata], documentation: [String]) {
            self.name = name
            _arguments = arguments
            self.documentation = documentation
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try name.encode(scaleEncoder: scaleEncoder)
            try _arguments.encode(scaleEncoder: scaleEncoder)
            try documentation.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            name = try String(scaleDecoder: scaleDecoder)
            _arguments = try [FunctionArgumentMetadata](scaleDecoder: scaleDecoder)
            documentation = try [String](scaleDecoder: scaleDecoder)
        }
    }
}

// MARK: - V14

public extension RuntimeMetadataV14 {
    struct FunctionMetadata: RuntimeFunctionMetadata {
        public let name: String
        public let callIndex: UInt8?
        private let _arguments: [FunctionArgumentMetadata]
        public var arguments: [RuntimeFunctionArgumentMetadata] { _arguments }
        public let documentation: [String]

        public init(item: TypeMetadata.Def.Variant.Item, schemaResolver: Schema.Resolver) throws {
            name = item.name
            callIndex = item.index
            _arguments = try item.fields.map {
                guard let name = $0.name else {
                    throw Schema.Resolver.Error.wrongData
                }
                let typeName = try schemaResolver.typeName(for: $0.type)
                return FunctionArgumentMetadata(name: name, type: typeName)
            }
            documentation = item.docs
        }
    }
}
