import BigInt
import Foundation

// MARK: - TypeMetadata

public struct TypeMetadata {
    public let path: [String]
    public let params: [Param]
    public let def: Def
    public let docs: [String]
}

extension TypeMetadata: Codable & Equatable {}

// MARK: TypeMetadata.Param

public extension TypeMetadata {
    struct Param: ScaleCodable {
        public let name: String
        public let type: BigUInt?

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try name.encode(scaleEncoder: scaleEncoder)
            try ScaleOption(value: type).encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            name = try String(scaleDecoder: scaleDecoder)
            type = try ScaleOption(scaleDecoder: scaleDecoder).value
        }
    }
}

extension TypeMetadata.Param: Codable & Equatable {}

extension TypeMetadata: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try path.encode(scaleEncoder: scaleEncoder)
        try params.encode(scaleEncoder: scaleEncoder)
        try def.encode(scaleEncoder: scaleEncoder)
        try docs.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        path = try [String](scaleDecoder: scaleDecoder)
        params = try [Param](scaleDecoder: scaleDecoder)
        def = try Def(scaleDecoder: scaleDecoder)
        docs = try [String](scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def

public extension TypeMetadata {
    enum Def {
        case composite(Composite)
        case variant(Variant)
        case sequence(Sequence)
        case array(Array)
        case tuple([BigUInt])
        case primitive(Primitive)
        case compact(Compact)
        case bitSequence(BitSequence)
    }
}

extension TypeMetadata.Def: Codable & Equatable {
    static let compositeField = "composite"
    static let variantField = "variant"
    static let sequenceField = "sequence"
    static let arrayField = "array"
    static let tupleField = "tuple"
    static let primitiveField = "primitive"
    static let compactField = "compact"
    static let bitSequenceField = "bitSequence"

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.compositeField:
            let composite = try container.decode(Composite.self)
            self = .composite(composite)
        case Self.variantField:
            let variant = try container.decode(Variant.self)
            self = .variant(variant)
        case Self.sequenceField:
            let sequence = try container.decode(Sequence.self)
            self = .sequence(sequence)
        case Self.arrayField:
            let array = try container.decode(Array.self)
            self = .array(array)
        case Self.tupleField:
            let tuple = try container.decode([BigUInt].self)
            self = .tuple(tuple)
        case Self.primitiveField:
            let primitive = try container.decode(Primitive.self)
            self = .primitive(primitive)
        case Self.compactField:
            let compact = try container.decode(Compact.self)
            self = .compact(compact)
        case Self.bitSequenceField:
            let bitSequence = try container.decode(BitSequence.self)
            self = .bitSequence(bitSequence)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .composite(composite):
            try container.encode(Self.compositeField)
            try container.encode(composite)
        case let .variant(variant):
            try container.encode(Self.variantField)
            try container.encode(variant)
        case let .sequence(sequence):
            try container.encode(Self.sequenceField)
            try container.encode(sequence)
        case let .array(array):
            try container.encode(Self.arrayField)
            try container.encode(array)
        case let .tuple(tuple):
            try container.encode(Self.tupleField)
            try container.encode(tuple)
        case let .primitive(primitive):
            try container.encode(Self.primitiveField)
            try container.encode(primitive)
        case let .compact(compact):
            try container.encode(Self.compactField)
            try container.encode(compact)
        case let .bitSequence(bitSequence):
            try container.encode(Self.bitSequenceField)
            try container.encode(bitSequence)
        }
    }

    public static func == (_: TypeMetadata.Def, _: TypeMetadata.Def) -> Bool {
        true //
    }
}

extension TypeMetadata.Def: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        let index: UInt8
        let encoding: ScaleCodable
        switch self {
        case let .composite(value):
            index = 0
            encoding = value
        case let .variant(value):
            index = 1
            encoding = value
        case let .sequence(value):
            index = 2
            encoding = value
        case let .array(value):
            index = 3
            encoding = value
        case let .tuple(value):
            index = 4
            encoding = value
        case let .primitive(value):
            index = 5
            encoding = value
        case let .compact(value):
            index = 6
            encoding = value
        case let .bitSequence(value):
            index = 7
            encoding = value
        }

        try index.encode(scaleEncoder: scaleEncoder)
        try encoding.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        let index = try UInt8(scaleDecoder: scaleDecoder)
        switch index {
        case 0: self = try .composite(Composite(scaleDecoder: scaleDecoder))
        case 1: self = try .variant(Variant(scaleDecoder: scaleDecoder))
        case 2: self = try .sequence(Sequence(scaleDecoder: scaleDecoder))
        case 3: self = try .array(Array(scaleDecoder: scaleDecoder))
        case 4: self = try .tuple([BigUInt](scaleDecoder: scaleDecoder))
        case 5: self = try .primitive(Primitive(scaleDecoder: scaleDecoder))
        case 6: self = try .compact(Compact(scaleDecoder: scaleDecoder))
        case 7: self = try .bitSequence(BitSequence(scaleDecoder: scaleDecoder))
        default:
            throw DecodingError.typeMismatch(
                Self.self,
                .init(
                    codingPath: [],
                    debugDescription: "Unexpected kind of TypeMetadata.Def: \(index)",
                    underlyingError: nil
                )
            )
        }
    }
}

// MARK: TypeMetadata.Def.Composite

public extension TypeMetadata.Def {
    struct Composite {
        public let fields: [Field]
    }
}

extension TypeMetadata.Def.Composite: Codable & Equatable {}

extension TypeMetadata.Def.Composite: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try fields.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        fields = try [Field](scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def.Composite.Field

public extension TypeMetadata.Def.Composite {
    struct Field {
        public let name: String?
        public let type: BigUInt
        public let typeName: String?
        public let docs: [String]
    }
}

extension TypeMetadata.Def.Composite.Field: Codable & Equatable {}

extension TypeMetadata.Def.Composite.Field: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try ScaleOption(value: name).encode(scaleEncoder: scaleEncoder)
        try type.encode(scaleEncoder: scaleEncoder)
        try ScaleOption(value: typeName).encode(scaleEncoder: scaleEncoder)
        try docs.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        name = try ScaleOption<String>(scaleDecoder: scaleDecoder).value
        type = try BigUInt(scaleDecoder: scaleDecoder)
        typeName = try ScaleOption<String>(scaleDecoder: scaleDecoder).value
        docs = try [String](scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def.Variant

public extension TypeMetadata.Def {
    struct Variant {
        public let variants: [Item]
    }
}

extension TypeMetadata.Def.Variant: Codable & Equatable {}

extension TypeMetadata.Def.Variant: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try variants.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        variants = try [Item](scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def.Variant.Item

public extension TypeMetadata.Def.Variant {
    struct Item {
        public let name: String
        public let fields: [TypeMetadata.Def.Composite.Field]
        public let index: UInt8
        public let docs: [String]
    }
}

extension TypeMetadata.Def.Variant.Item: Codable & Equatable {}

extension TypeMetadata.Def.Variant.Item: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try name.encode(scaleEncoder: scaleEncoder)
        try fields.encode(scaleEncoder: scaleEncoder)
        try index.encode(scaleEncoder: scaleEncoder)
        try docs.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        name = try String(scaleDecoder: scaleDecoder)
        fields = try [TypeMetadata.Def.Composite.Field](scaleDecoder: scaleDecoder)
        index = try UInt8(scaleDecoder: scaleDecoder)
        docs = try [String](scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def.Sequence

public extension TypeMetadata.Def {
    struct Sequence {
        public let type: BigUInt
    }
}

extension TypeMetadata.Def.Sequence: Codable & Equatable {}

extension TypeMetadata.Def.Sequence: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try type.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        type = try BigUInt(scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def.Array

public extension TypeMetadata.Def {
    struct Array {
        public let length: UInt32
        public let type: BigUInt
    }
}

extension TypeMetadata.Def.Array: Codable & Equatable {}

extension TypeMetadata.Def.Array: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try length.encode(scaleEncoder: scaleEncoder)
        try type.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        length = try UInt32(scaleDecoder: scaleDecoder)
        type = try BigUInt(scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def.Primitive

public extension TypeMetadata.Def {
    enum Primitive: UInt8 {
        case bool
        case char
        case string
        case u8
        case u16
        case u32
        case u64
        case u128
        case u256
        case i8
        case i16
        case i32
        case i64
        case i128
        case i256
    }
}

extension TypeMetadata.Def.Primitive: Codable & Equatable {}

extension TypeMetadata.Def.Primitive: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try rawValue.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        let rawValue = try UInt8(scaleDecoder: scaleDecoder)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.typeMismatch(
                Self.self,
                .init(
                    codingPath: [],
                    debugDescription: "Unexpected kind of TypeMetadata.Def.Primitive: \(rawValue)",
                    underlyingError: nil
                )
            )
        }

        self = value
    }
}

// MARK: TypeMetadata.Def.Compact

public extension TypeMetadata.Def {
    struct Compact {
        public let type: BigUInt
    }
}

extension TypeMetadata.Def.Compact: Codable & Equatable {}

extension TypeMetadata.Def.Compact: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try type.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        type = try BigUInt(scaleDecoder: scaleDecoder)
    }
}

// MARK: TypeMetadata.Def.BitSequence

public extension TypeMetadata.Def {
    struct BitSequence {
        public let store: BigUInt
        public let order: BigUInt
    }
}

extension TypeMetadata.Def.BitSequence: Codable & Equatable {}

extension TypeMetadata.Def.BitSequence: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try store.encode(scaleEncoder: scaleEncoder)
        try order.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        store = try BigUInt(scaleDecoder: scaleDecoder)
        order = try BigUInt(scaleDecoder: scaleDecoder)
    }
}
