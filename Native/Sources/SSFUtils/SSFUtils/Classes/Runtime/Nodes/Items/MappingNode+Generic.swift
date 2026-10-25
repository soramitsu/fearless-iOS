import Foundation

public extension MappingNode {
    static var consensus: MappingNode {
        MappingNode(
            typeName: GenericType.consensus.rawValue,
            typeMapping: [
                NamedType(name: "engineId", type: GenericType.consensusEngineId.name),
                NamedType(name: "data", type: GenericType.bytes.rawValue),
            ]
        )
    }

    static var seal: MappingNode {
        MappingNode(
            typeName: GenericType.seal.rawValue,
            typeMapping: [
                NamedType(name: "engineId", type: GenericType.consensusEngineId.name),
                NamedType(name: "data", type: GenericType.bytes.rawValue),
            ]
        )
    }

    static var sealv0: MappingNode {
        MappingNode(
            typeName: GenericType.sealv0.rawValue,
            typeMapping: [
                NamedType(name: "slot", type: PrimitiveType.u64.rawValue),
                NamedType(name: "signature", type: GenericType.signature.rawValue),
            ]
        )
    }

    static var preRuntime: MappingNode {
        MappingNode(
            typeName: GenericType.preRuntime.rawValue,
            typeMapping: [
                NamedType(name: "engineId", type: GenericType.consensusEngineId.name),
                NamedType(name: "data", type: GenericType.bytes.rawValue),
            ]
        )
    }
}
