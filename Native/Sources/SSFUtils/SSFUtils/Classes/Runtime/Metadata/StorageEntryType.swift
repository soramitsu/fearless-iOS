import BigInt
import Foundation

public enum StorageEntryTypeError: Error {
    case unableToFetchKey
}

public enum StorageEntryType {
    case plain(_ value: PlainEntry)
    case map(_ value: MapEntry)
    case doubleMap(_ value: DoubleMapEntry)
    case nMap(_ value: NMapEntry)

    public func typeName(using schemaResolver: Schema.Resolver) throws -> String {
        switch self {
        case let .plain(plain):
            return try plain.value(using: schemaResolver)
        case let .map(singleMap):
            return singleMap.value
        case let .doubleMap(doubleMap):
            return doubleMap.value
        case let .nMap(nMap):
            return try nMap.value(using: schemaResolver)
        }
    }

    public func keyName(schemaResolver: Schema.Resolver) throws -> String? {
        switch self {
        case let .map(singleMap):
            return singleMap.key
        case let .nMap(nMap):
            let keys = try nMap.keyEntries.map { try $0.value(using: schemaResolver) }
            guard keys.count == 1 else {
                throw StorageEntryTypeError.unableToFetchKey
            }

            return keys.first
        default:
            return nil
        }
    }
    
    public func hashers(schemaResolver: Schema.Resolver) throws -> [StorageHasher] {
        switch self {
        case .plain:
            return []
        case .map(let value):
            return [value.hasher]
        case .doubleMap(let value):
            return [value.hasher, value.key2Hasher]
        case .nMap(let value):
            return value.hashers
        }
    }
}

extension StorageEntryType: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case let .plain(value):
            try UInt8(0).encode(scaleEncoder: scaleEncoder)
            try value.encode(scaleEncoder: scaleEncoder)
        case let .map(value):
            try UInt8(1).encode(scaleEncoder: scaleEncoder)
            try value.encode(scaleEncoder: scaleEncoder)
        case let .doubleMap(value):
            try UInt8(2).encode(scaleEncoder: scaleEncoder)
            try value.encode(scaleEncoder: scaleEncoder)
        case let .nMap(value):
            if value.v14 {
                try UInt8(1).encode(scaleEncoder: scaleEncoder)
            } else {
                try UInt8(3).encode(scaleEncoder: scaleEncoder)
            }
            try value.encode(scaleEncoder: scaleEncoder)
        }
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        let rawValue = try UInt8(scaleDecoder: scaleDecoder)

        switch rawValue {
        case 0:
            let value = try PlainEntry(scaleDecoder: scaleDecoder)
            self = .plain(value)
        case 1:
            let value = try MapEntry(scaleDecoder: scaleDecoder)
            self = .map(value)
        case 2:
            let value = try DoubleMapEntry(scaleDecoder: scaleDecoder)
            self = .doubleMap(value)
        case 3:
            let value = try NMapEntry(scaleDecoder: scaleDecoder)
            self = .nMap(value)
        default:
            throw ScaleCodingError.unexpectedDecodedValue
        }
    }

    init(v14ScaleDecoder scaleDecoder: ScaleDecoding) throws {
        let rawValue = try UInt8(scaleDecoder: scaleDecoder)

        switch rawValue {
        case 0:
            let value = try PlainEntry(v14ScaleDecoder: scaleDecoder)
            self = .plain(value)
        case 1:
            let value = try NMapEntry(v14ScaleDecoder: scaleDecoder)
            self = .nMap(value)
        default:
            throw ScaleCodingError.unexpectedDecodedValue
        }
    }
}

public struct PlainEntry {
    public let stringValue: String?
    public let index: BigUInt?

    public init(stringValue: String) {
        self.stringValue = stringValue
        index = nil
    }

    public init(index: BigUInt) {
        stringValue = nil
        self.index = index
    }

    fileprivate func typeMetadata(using schemaResolver: Schema.Resolver) throws -> TypeMetadata {
        try schemaResolver.typeMetadata(for: index)
    }

    public func value(using schemaResolver: Schema.Resolver) throws -> String {
        if let stringValue = stringValue {
            return stringValue
        }

        return try schemaResolver.typeName(for: index)
    }
}

extension PlainEntry: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        assert((stringValue == nil) != (index == nil))
        try stringValue.map { try $0.encode(scaleEncoder: scaleEncoder) }
        try index.map { try $0.encode(scaleEncoder: scaleEncoder) }
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        stringValue = try String(scaleDecoder: scaleDecoder)
        index = nil
    }

    public init(v14ScaleDecoder scaleDecoder: ScaleDecoding) throws {
        stringValue = nil
        index = try BigUInt(scaleDecoder: scaleDecoder)
    }
}

public struct MapEntry {
    public let hasher: StorageHasher
    public let key: String
    public let value: String
    public let unused: Bool

    public init(hasher: StorageHasher, key: String, value: String, unused: Bool) {
        self.hasher = hasher
        self.key = key
        self.value = value
        self.unused = unused
    }
}

extension MapEntry: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try hasher.encode(scaleEncoder: scaleEncoder)
        try key.encode(scaleEncoder: scaleEncoder)
        try value.encode(scaleEncoder: scaleEncoder)
        try unused.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        hasher = try StorageHasher(scaleDecoder: scaleDecoder)
        key = try String(scaleDecoder: scaleDecoder)
        value = try String(scaleDecoder: scaleDecoder)
        unused = try Bool(scaleDecoder: scaleDecoder)
    }
}

public struct DoubleMapEntry {
    public let hasher: StorageHasher
    public let key1: String
    public let key2: String
    public let value: String
    public let key2Hasher: StorageHasher

    public init(
        hasher: StorageHasher,
        key1: String,
        key2: String,
        value: String,
        key2Hasher: StorageHasher
    ) {
        self.hasher = hasher
        self.key1 = key1
        self.key2 = key2
        self.value = value
        self.key2Hasher = key2Hasher
    }
}

extension DoubleMapEntry: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try hasher.encode(scaleEncoder: scaleEncoder)
        try key1.encode(scaleEncoder: scaleEncoder)
        try key2.encode(scaleEncoder: scaleEncoder)
        try value.encode(scaleEncoder: scaleEncoder)
        try key2Hasher.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        hasher = try StorageHasher(scaleDecoder: scaleDecoder)
        key1 = try String(scaleDecoder: scaleDecoder)
        key2 = try String(scaleDecoder: scaleDecoder)
        value = try String(scaleDecoder: scaleDecoder)
        key2Hasher = try StorageHasher(scaleDecoder: scaleDecoder)
    }
}

public struct NMapEntry {
    fileprivate let v14: Bool
    public let keyEntries: [PlainEntry]
    public let hashers: [StorageHasher]
    private let valueEntry: PlainEntry

    public func keys(using schemaResolver: Schema.Resolver) throws -> [String] {
        let entries: [PlainEntry]
        if v14 {
            guard keyEntries.count == 1, let entry = keyEntries.first else {
                throw Schema.Resolver.Error.wrongData
            }

            let typeMetadata = try entry.typeMetadata(using: schemaResolver)
            switch typeMetadata.def {
            case let .tuple(indices):
                entries = indices.map { PlainEntry(index: $0) }
            default:
                entries = keyEntries
            }
        } else {
            entries = keyEntries
        }

        return try entries.map { try $0.value(using: schemaResolver) }
    }

    public func value(using schemaResolver: Schema.Resolver) throws -> String {
        try valueEntry.value(using: schemaResolver)
    }

    public init(keysStrings: [String], hashers: [StorageHasher], valueString: String) {
        v14 = false
        keyEntries = keysStrings.map { PlainEntry(stringValue: $0) }
        self.hashers = hashers
        valueEntry = PlainEntry(stringValue: valueString)
    }

    public init(keysIndices: [BigUInt], hashers: [StorageHasher], valueIndex: BigUInt) {
        v14 = true
        keyEntries = keysIndices.map { PlainEntry(index: $0) }
        self.hashers = hashers
        valueEntry = PlainEntry(index: valueIndex)
    }
}

extension NMapEntry: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        if v14 {
            // In V14 different order, and key entry is single value
            try hashers.encode(scaleEncoder: scaleEncoder)
            assert(keyEntries.count == 1)
            try keyEntries.first?.encode(scaleEncoder: scaleEncoder)
        } else {
            try keyEntries.encode(scaleEncoder: scaleEncoder)
            try hashers.encode(scaleEncoder: scaleEncoder)
        }
        try valueEntry.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        v14 = false
        keyEntries = try [PlainEntry](scaleDecoder: scaleDecoder)
        hashers = try [StorageHasher](scaleDecoder: scaleDecoder)
        valueEntry = try PlainEntry(scaleDecoder: scaleDecoder)
    }

    public init(v14ScaleDecoder scaleDecoder: ScaleDecoding) throws {
        v14 = true
        hashers = try [StorageHasher](scaleDecoder: scaleDecoder)
        keyEntries = try [PlainEntry(v14ScaleDecoder: scaleDecoder)]
        valueEntry = try PlainEntry(v14ScaleDecoder: scaleDecoder)
    }
}

// MARK: - StorageHasher::ScaleCodable

extension StorageHasher: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try rawValue.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        let rawValue = try UInt8(scaleDecoder: scaleDecoder)

        guard let value = StorageHasher(rawValue: rawValue) else {
            throw ScaleCodingError.unexpectedDecodedValue
        }

        self = value
    }
}
