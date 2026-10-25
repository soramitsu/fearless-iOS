import BigInt
import Foundation
import SSFModels

public protocol RuntimeMetadataProtocol: ScaleCodable {
    var schema: Schema? { get }
    var modules: [RuntimeModuleMetadata] { get }
    var extrinsic: RuntimeExtrinsicMetadata { get }
}

public final class RuntimeMetadata {
    public let metaReserved: UInt32
    public let version: UInt8
    public let schemaResolver: Schema.Resolver

    public var signatureType: String {
        if version == 13 {
            return KnownType.signature13.rawValue
        }

        return KnownType.signature.rawValue
    }

    private let wrapped: RuntimeMetadataProtocol
    public init(
        wrapping runtimeMetadata: RuntimeMetadataProtocol,
        metaReserved: UInt32,
        version: UInt8
    ) throws {
        self.metaReserved = metaReserved
        self.version = version
        wrapped = runtimeMetadata
        schemaResolver = try Schema.Resolver(schema: wrapped.schema)
    }

    public func getFunction(
        from module: String,
        with name: String
    ) throws -> RuntimeFunctionMetadata? {
        try wrapped.modules
            .first { $0.name.lowercased() == module.lowercased() }?
            .calls(using: schemaResolver)?
            .first { $0.name.lowercased() == name.lowercased() }
    }

    public func getModuleIndex(_ name: String) -> UInt8? {
        wrapped.modules.first(where: { $0.name.lowercased() == name.lowercased() })?.index
    }

    /// Index the runtime dispatches `callName` of `moduleName` by.
    ///
    /// This is the index the metadata declares for the call, not its position in the pallet's
    /// call list: pallets leave gaps in their indexes, so the two differ.
    public func getCallIndex(in moduleName: String, callName: String) throws -> UInt8? {
        guard let calls = try wrapped.modules
            .first(where: { $0.name.lowercased() == moduleName.lowercased() })?
            .calls(using: schemaResolver) else
        {
            return nil
        }

        guard let position = calls.firstIndex(where: {
            $0.name.lowercased() == callName.lowercased()
        }) else {
            return nil
        }

        return Self.callIndex(of: calls[position], at: position)
    }

    /// The call of `module` the runtime dispatches for `callIndex`, if there is one.
    public func getFunction(
        in module: RuntimeModuleMetadata,
        at callIndex: UInt8
    ) throws -> RuntimeFunctionMetadata? {
        try module.calls(using: schemaResolver)?
            .enumerated()
            .first { Self.callIndex(of: $0.element, at: $0.offset) == callIndex }?
            .element
    }

    private static func callIndex(
        of function: RuntimeFunctionMetadata,
        at position: Int
    ) -> UInt8? {
        function.callIndex ?? UInt8(exactly: position)
    }

    /// The event of `module` the runtime emits under `eventIndex`, if there is one. Like calls,
    /// events are identified by the index the metadata declares, not by their position in the list.
    public func getEvent(
        in module: RuntimeModuleMetadata,
        at eventIndex: UInt8
    ) throws -> RuntimeEventMetadata? {
        try module.events(using: schemaResolver)?
            .enumerated()
            .first { ($0.element.eventIndex ?? UInt8(exactly: $0.offset)) == eventIndex }?
            .element
    }

    public func getStorageMetadata(
        in moduleName: String,
        storageName: String
    ) -> RuntimeStorageEntryMetadata? {
        wrapped.modules.first(where: { $0.name.lowercased() == moduleName.lowercased() })?
            .storage?.entries.first(where: { $0.name.lowercased() == storageName.lowercased() })
    }

    public func getConstant(
        in moduleName: String,
        constantName: String
    ) -> RuntimeModuleConstantMetadata? {
        wrapped.modules.first(where: { $0.name.lowercased() == moduleName.lowercased() })?
            .constants.first(where: { $0.name.lowercased() == constantName.lowercased() })
    }

    public func checkArgument(
        moduleName: String,
        callName: String,
        argumentName: String
    ) throws -> Bool {
        try wrapped.modules
            .first(where: { $0.name.lowercased() == moduleName.lowercased() })?
            .calls(using: schemaResolver)?
            .first(where: { $0.name.lowercased() == callName.lowercased() })?
            .arguments
            .first(where: { $0.name.lowercased() == argumentName.lowercased() }) != nil
    }

    public func multiAddressParameter(
        accountId: AccountId,
        chainFormat: SFChainFormat
    ) -> MultiAddress {
        switch chainFormat {
        case .sfEthereum:
            return MultiAddress.address20(accountId)
        case .sfSubstrate:
            if version == 13 {
                return .indexedString(accountId)
            } else {
                return MultiAddress.accoundId(accountId)
            }
        }
    }
}

extension RuntimeMetadata: RuntimeMetadataProtocol {
    public var schema: Schema? { wrapped.schema }
    public var modules: [RuntimeModuleMetadata] { wrapped.modules }
    public var extrinsic: RuntimeExtrinsicMetadata { wrapped.extrinsic }
}

extension RuntimeMetadata: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try metaReserved.encode(scaleEncoder: scaleEncoder)
        try version.encode(scaleEncoder: scaleEncoder)
        try wrapped.encode(scaleEncoder: scaleEncoder)
    }

    public convenience init(scaleDecoder: ScaleDecoding) throws {
        let metaReserved = try UInt32(scaleDecoder: scaleDecoder)
        let version = try UInt8(scaleDecoder: scaleDecoder)

        let wrapped: RuntimeMetadataProtocol
        if version >= 14 {
            wrapped = try RuntimeMetadataV14(scaleDecoder: scaleDecoder)
        } else {
            wrapped = try RuntimeMetadataV1(scaleDecoder: scaleDecoder)
        }

        try self.init(wrapping: wrapped, metaReserved: metaReserved, version: version)
    }
}

public extension RuntimeMetadata {
    static func v1(
        modules: [RuntimeMetadataV1.ModuleMetadata],
        extrinsic: RuntimeMetadataV1.ExtrinsicMetadata
    ) throws -> RuntimeMetadata {
        try .init(
            wrapping: RuntimeMetadataV1(modules: modules, extrinsic: extrinsic),
            metaReserved: 1,
            version: 1
        )
    }

    static func v14(
        types: [SchemaItem],
        modules: [RuntimeMetadataV14.ModuleMetadata],
        extrinsic: RuntimeMetadataV14.ExtrinsicMetadata
    ) throws -> RuntimeMetadata {
        try .init(
            wrapping: RuntimeMetadataV14(
                types: types,
                modules: modules,
                extrinsic: extrinsic,
                type: 603
            ),
            metaReserved: 14,
            version: 14
        )
    }
}

// MARK: - RuntimeMetadata V1

public struct RuntimeMetadataV1: RuntimeMetadataProtocol, ScaleCodable {
    public let schema: Schema? = nil
    public let resolver: Schema.Resolver? = nil

    private let _modules: [ModuleMetadata]
    public var modules: [RuntimeModuleMetadata] { _modules }

    private let _extrinsic: ExtrinsicMetadata
    public var extrinsic: RuntimeExtrinsicMetadata { _extrinsic }

    init(modules: [ModuleMetadata], extrinsic: ExtrinsicMetadata) {
        _modules = modules
        _extrinsic = extrinsic
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try _modules.encode(scaleEncoder: scaleEncoder)
        try _extrinsic.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        _modules = try [ModuleMetadata](scaleDecoder: scaleDecoder)
        _extrinsic = try ExtrinsicMetadata(scaleDecoder: scaleDecoder)
    }
}

// MARK: - RuntimeMetadata V14

public struct RuntimeMetadataV14: RuntimeMetadataProtocol, ScaleCodable {
    private let _schema: Schema
    public var schema: Schema? { _schema }

    private let _modules: [ModuleMetadata]
    public var modules: [RuntimeModuleMetadata] { _modules }

    private let _extrinsic: ExtrinsicMetadata
    public var extrinsic: RuntimeExtrinsicMetadata { _extrinsic }

    private let type: BigUInt

    init(
        types: [SchemaItem],
        modules: [ModuleMetadata],
        extrinsic: ExtrinsicMetadata,
        type: BigUInt
    ) {
        _schema = Schema(types: types)
        _modules = modules
        _extrinsic = extrinsic
        self.type = type
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try _schema.encode(scaleEncoder: scaleEncoder)
        try _modules.encode(scaleEncoder: scaleEncoder)
        try _extrinsic.encode(scaleEncoder: scaleEncoder)
        try type.encode(scaleEncoder: scaleEncoder)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        _schema = try Schema(scaleDecoder: scaleDecoder)
        _modules = try [ModuleMetadata](scaleDecoder: scaleDecoder)
        _extrinsic = try ExtrinsicMetadata(scaleDecoder: scaleDecoder)
        type = try BigUInt(scaleDecoder: scaleDecoder)
    }
}
