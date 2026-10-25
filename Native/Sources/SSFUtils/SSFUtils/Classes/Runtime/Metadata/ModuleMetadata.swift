import BigInt
import Foundation

// MARK: - Protocol

public protocol RuntimeModuleMetadata {
    var name: String { get }
    var storage: RuntimeStorageMetadata? { get }
    func calls(using schemaResolver: Schema.Resolver) throws -> [RuntimeFunctionMetadata]?
    func events(using schemaResolver: Schema.Resolver) throws -> [RuntimeEventMetadata]?
    var constants: [RuntimeModuleConstantMetadata] { get }
    func errors(using schemaResolver: Schema.Resolver) throws -> [RuntimeErrorMetadata]?
    var index: UInt8 { get }
}

// MARK: - ModuleMetadata V1

public extension RuntimeMetadataV1 {
    struct ModuleMetadata: ScaleCodable {
        public let name: String

        private let _storage: StorageMetadata?
        private let _calls: [FunctionMetadata]?
        private let _events: [EventMetadata]?
        private let _constants: [ModuleConstantMetadata]
        private let _errors: [ErrorMetadata]

        public let index: UInt8

        public init(
            name: String,
            storage: StorageMetadata?,
            calls: [FunctionMetadata]?,
            events: [EventMetadata]?,
            constants: [ModuleConstantMetadata],
            errors: [ErrorMetadata],
            index: UInt8
        ) {
            self.name = name

            _storage = storage
            _calls = calls
            _events = events
            _constants = constants
            _errors = errors

            self.index = index
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try name.encode(scaleEncoder: scaleEncoder)

            try ScaleOption(value: _storage).encode(scaleEncoder: scaleEncoder)
            try ScaleOption(value: _calls).encode(scaleEncoder: scaleEncoder)
            try ScaleOption(value: _events).encode(scaleEncoder: scaleEncoder)
            try _constants.encode(scaleEncoder: scaleEncoder)
            try _errors.encode(scaleEncoder: scaleEncoder)

            try index.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            name = try String(scaleDecoder: scaleDecoder)

            _storage = try ScaleOption(scaleDecoder: scaleDecoder).value
            _calls = try ScaleOption(scaleDecoder: scaleDecoder).value
            _events = try ScaleOption(scaleDecoder: scaleDecoder).value
            _constants = try [ModuleConstantMetadata](scaleDecoder: scaleDecoder)
            _errors = try [ErrorMetadata](scaleDecoder: scaleDecoder)

            index = try UInt8(scaleDecoder: scaleDecoder)
        }
    }
}

extension RuntimeMetadataV1.ModuleMetadata: RuntimeModuleMetadata {
    public var storage: RuntimeStorageMetadata? { _storage }
    public func calls(using _: Schema.Resolver) throws -> [RuntimeFunctionMetadata]? { _calls }
    public func events(using _: Schema.Resolver) throws -> [RuntimeEventMetadata]? { _events }
    public var events: [RuntimeEventMetadata]? { _events }
    public var constants: [RuntimeModuleConstantMetadata] { _constants }
    public func errors(using _: Schema.Resolver) throws -> [RuntimeErrorMetadata]? { _errors }
}

// MARK: - ModuleMetadata V14

public extension RuntimeMetadataV14 {
    struct ModuleMetadata: ScaleCodable {
        public let name: String

        private let _storage: StorageMetadata?
        private let callsIndex: BigUInt?
        private let eventsIndex: BigUInt?
        private let _constants: [ModuleConstantMetadata]
        private let errorsIndex: BigUInt?

        public let index: UInt8

        public init(
            name: String,
            storage: StorageMetadata?,
            callsIndex: BigUInt?,
            eventsIndex: BigUInt?,
            constants: [ModuleConstantMetadata],
            errorsIndex: BigUInt?,
            index: UInt8
        ) {
            self.name = name

            _storage = storage
            self.callsIndex = callsIndex
            self.eventsIndex = eventsIndex
            _constants = constants
            self.errorsIndex = errorsIndex

            self.index = index
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try name.encode(scaleEncoder: scaleEncoder)

            try ScaleOption(value: _storage).encode(scaleEncoder: scaleEncoder)
            try ScaleOption(value: callsIndex).encode(scaleEncoder: scaleEncoder)
            try ScaleOption(value: eventsIndex).encode(scaleEncoder: scaleEncoder)
            try _constants.encode(scaleEncoder: scaleEncoder)
            try ScaleOption(value: errorsIndex).encode(scaleEncoder: scaleEncoder)

            try index.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            name = try String(scaleDecoder: scaleDecoder)

            _storage = try ScaleOption(scaleDecoder: scaleDecoder).value
            callsIndex = try ScaleOption(scaleDecoder: scaleDecoder).value
            eventsIndex = try ScaleOption(scaleDecoder: scaleDecoder).value
            _constants = try [ModuleConstantMetadata](scaleDecoder: scaleDecoder)
            errorsIndex = try ScaleOption(scaleDecoder: scaleDecoder).value

            index = try UInt8(scaleDecoder: scaleDecoder)
        }
    }
}

extension RuntimeMetadataV14.ModuleMetadata: RuntimeModuleMetadata {
    public var storage: RuntimeStorageMetadata? { _storage }
    public var constants: [RuntimeModuleConstantMetadata] { _constants }

    public func calls(using schemaResolver: Schema.Resolver) throws -> [RuntimeFunctionMetadata]? {
        guard let callsIndex = callsIndex else { return nil }

        let typeMetadata = try schemaResolver.typeMetadata(for: callsIndex)
        switch typeMetadata.def {
        case let .variant(variant):
            return try variant.variants.map {
                try RuntimeMetadataV14.FunctionMetadata(item: $0, schemaResolver: schemaResolver)
            }
        default:
            throw Schema.Resolver.Error.wrongData
        }
    }

    public func events(using schemaResolver: Schema.Resolver) throws -> [RuntimeEventMetadata]? {
        guard let eventsIndex = eventsIndex else { return nil }

        let typeMetadata = try schemaResolver.typeMetadata(for: eventsIndex)
        switch typeMetadata.def {
        case let .variant(variant):
            return try variant.variants.map {
                try RuntimeMetadataV14.EventMetadata(item: $0, schemaResolver: schemaResolver)
            }
        default:
            throw Schema.Resolver.Error.wrongData
        }
    }

    public func errors(using schemaResolver: Schema.Resolver) throws -> [RuntimeErrorMetadata]? {
        guard let errorsIndex = errorsIndex else { return nil }

        let typeMetadata = try schemaResolver.typeMetadata(for: errorsIndex)
        switch typeMetadata.def {
        case let .variant(variant):
            return variant.variants.map {
                RuntimeMetadataV14.ErrorMetadata(name: $0.name, documentation: $0.docs)
            }
        default:
            throw Schema.Resolver.Error.wrongData
        }
    }
}
