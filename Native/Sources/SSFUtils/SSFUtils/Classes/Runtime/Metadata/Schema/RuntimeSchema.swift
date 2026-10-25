import BigInt
import Foundation

// MARK: - Schema

public struct Schema: ScaleCodable {
    public let types: [SchemaItem]

    public init(types: [SchemaItem]) {
        self.types = types
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try types.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        types = try [SchemaItem](scaleDecoder: scaleDecoder)
    }
}

extension Schema: Codable & Equatable {
    public static func == (lhs: Schema, rhs: Schema) -> Bool {
        lhs.types == rhs.types
    }
}

// MARK: - Resolver

public extension Schema {
    final class Resolver: Codable & Equatable {
        // MARK: - Private properties

        private let schema: Schema?
        private var resolvedTypes: [String: TypeMetadata?] = [:]

        enum CodingKeys: String, CodingKey {
            case schema
            case resolvedTypes
        }

        // MARK: - Constructor

        public init(schema: Schema?) throws {
            self.schema = schema
            try mapSchemaToDictionary()
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            schema = try container.decode(Schema.self, forKey: .schema)
            resolvedTypes = try container.decode(
                [String: TypeMetadata?].self,
                forKey: .resolvedTypes
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(schema, forKey: .schema)
            try container.encode(resolvedTypes, forKey: .resolvedTypes)
        }

        public static func == (lhs: Schema.Resolver, rhs: Schema.Resolver) -> Bool {
            lhs.schema == rhs.schema
                && lhs.resolvedTypes == rhs.resolvedTypes
        }

        // MARK: - Public methods

        public func resolveType(json: JSON) throws -> TypeMetadata? {
            guard let string = json.stringValue else { return nil }

            if let index = BigUInt(string) {
                return try typeMetadata(for: index)
            }

            return try resolveType(name: string)
        }

        public func resolveType(name: String) throws -> TypeMetadata? {
            var metadata: TypeMetadata? = nil
            if let type = resolvedTypes[name] {
                metadata = type
            }

            return metadata
        }

        public func typeMetadata(for index: BigUInt?) throws -> TypeMetadata {
            guard let schema = schema else {
                throw Error.schemaNotProvided
            }

            guard let index = index else {
                throw Error.wrongData
            }

            guard let type = schema.types.first(where: { $0.id == index })?.type else {
                throw Error.keyNotFound
            }

            return type
        }

        public func typeName(for index: BigUInt?) throws -> String {
            try typeName(for: typeMetadata(for: index))
        }

        public func typeName(for type: TypeMetadata) throws -> String {
            let name = try _typeName(for: type)
            if resolvedTypes[name] == nil {
                resolvedTypes[name] = type
            }

            return name
        }

        // MARK: - Private methods

        private func mapSchemaToDictionary() throws {
            guard let items = schema?.types else {
                return
            }
            for schemaItem in items {
                _ = try typeName(for: schemaItem.type)
            }
        }

        private var ignoredGenericTypes: [String] {
            [KnownType.address.name] + ExtrinsicCheck.allCases.map { $0.rawValue }
        }

        // swiftlint:disable cyclomatic_complexity function_body_length
        private func _typeName(for type: TypeMetadata) throws -> String {
            switch type.def {
            case .composite, .variant:
                guard !type.path.isEmpty else {
                    throw Error.wrongData
                }
                var name = type.path.joined(separator: "::")

                if !type.params.isEmpty, !ignoredGenericTypes.contains(name) {
                    let paramNames = try type.params
                        .map {
                            var name = $0.name
                            if let typeName = try $0.type.map({ try typeName(for: $0) }) {
                                name += ": \(typeName)"
                            }

                            return name
                        }
                        .joined(separator: ", ")

                    name += "<\(paramNames)>"
                }

                return name

            case let .sequence(value):
                return try "Vec<\(typeName(for: value.type))>"

            case let .array(value):
                return try "[\(typeName(for: value.type)); \(value.length)]"

            case let .tuple(value):
                let paramNames = try value.map { try typeName(for: $0) }.joined(separator: ", ")
                return "(\(paramNames))"

            case let .primitive(value):
                switch value {
                case .bool: return "bool"
                case .char: return "char"
                case .string: return "str"
                case .u8: return "u8"
                case .u16: return "u16"
                case .u32: return "u32"
                case .u64: return "u64"
                case .u128: return "u128"
                case .u256: return "u256"
                case .i8: return "i8"
                case .i16: return "i16"
                case .i32: return "i32"
                case .i64: return "i64"
                case .i128: return "i128"
                case .i256: return "i256"
                }

            case let .compact(value):
                return try "Compact<\(typeName(for: value.type))>"

            case let .bitSequence(value):
                let paramNames = try [
                    typeName(for: value.order),
                    typeName(for: value.store),
                ].joined(separator: ", ")
                return "BitVec<\(paramNames)>"
            }
        }
    }
}

public extension Schema.Resolver {
    enum Error: Swift.Error {
        case schemaNotProvided
        case wrongData
        case keyNotFound
    }
}

// MARK: - Item

public struct SchemaItem: ScaleCodable {
    public let id: BigUInt
    public let type: TypeMetadata

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try id.encode(scaleEncoder: scaleEncoder)
        try type.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        id = try BigUInt(scaleDecoder: scaleDecoder)
        type = try TypeMetadata(scaleDecoder: scaleDecoder)
    }
}

extension SchemaItem: Codable & Equatable {}
