import BigInt
import Foundation

private extension JSON {
    static func typeId(_ id: BigUInt) -> JSON {
        .stringValue(String(id))
    }
}

class RuntimeSchemaNodeFactory: TypeNodeFactoryProtocol {
    let schemaResolver: Schema.Resolver

    init(schemaResolver: Schema.Resolver) {
        self.schemaResolver = schemaResolver
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        guard let type = try schemaResolver.resolveType(json: json) else { return nil }

        switch type.def {
        case let .composite(value):
            return try buildComposite(typeName: typeName, value: value, mediator: mediator)
        case let .variant(value):
            return try buildVariant(typeName: typeName, value: value, mediator: mediator)
        case let .sequence(value):
            return try buildSequence(typeName: typeName, value: value, mediator: mediator)
        case let .array(value):
            return try buildArray(typeName: typeName, value: value, mediator: mediator)
        case let .tuple(value):
            return try buildTuple(typeName: typeName, value: value, mediator: mediator)
        case let .primitive(value):
            return try buildPrimitive(typeName: typeName, value: value, mediator: mediator)
        case let .compact(value):
            return try buildCompact(typeName: typeName, value: value, mediator: mediator)
        case let .bitSequence(value):
            return try buildBitSequence(typeName: typeName, value: value, mediator: mediator)
        }
    }

    private func buildComposite(
        typeName: String,
        value: TypeMetadata.Def.Composite,
        mediator: TypeRegistering
    ) throws -> Node {
//        if value.fields.count == 1 {
//            // return ProxyNode for this type
//            let underlyingNode = try underlyingNode(for: value.fields[0].type, mediator: mediator)
//            return AliasNode(
//                typeName: typeName,
//                underlyingTypeName: underlyingNode.typeName
//            )
//        }

        let childrenNodes = try value.fields.enumerated().compactMap { index, field -> NameNode? in
            guard let name = field.name else { return nil }
            return try NameNode(
                name: name,
                node: underlyingNode(for: field.type, mediator: mediator),
                index: index
            )
        }

        if childrenNodes.count != value.fields.count {
            // unnamed fields
            let childrenTypes = value.fields.map { $0.type }
            return try buildTuple(typeName: typeName, value: childrenTypes, mediator: mediator)
        }

        return StructNode(typeName: typeName, typeMapping: childrenNodes)
    }

    private func buildOption(
        typeName: String,
        type: BigUInt,
        mediator: TypeRegistering
    ) throws -> Node {
        try OptionNode(
            typeName: typeName,
            underlying: underlyingNode(for: type, mediator: mediator)
        )
    }

    private func buildVariant(
        typeName: String,
        value: TypeMetadata.Def.Variant,
        mediator: TypeRegistering
    ) throws -> Node {
        if typeName.starts(with: "Option"),
           value.variants.count == 2,
           value.variants[0].name == "None",
           value.variants[1].name == "Some",
           value.variants[1].fields.count == 1,
           let optionType = value.variants[1].fields.first?.type
        {
            return try buildOption(typeName: typeName, type: optionType, mediator: mediator)
        }

        let childNodes = try value.variants.map { variant -> NameNode in
            let variantNode = try buildComposite(
                typeName: "\(typeName).\(variant.name)",
                // provide abstract type name for "struct" with list of fields
                value: .init(fields: variant.fields),
                mediator: mediator
            )

            // register this custom type with prepared node
            return NameNode(
                name: variant.name,
                node: mediator.register(typeName: variantNode.typeName, node: variantNode),
                index: variant.index
            )
        }

        return EnumNode(typeName: typeName, typeMapping: childNodes)
    }

    private func buildSequence(
        typeName: String,
        value: TypeMetadata.Def.Sequence,
        mediator: TypeRegistering
    ) throws -> Node {
        try VectorNode(
            typeName: typeName,
            underlying: underlyingNode(for: value.type, mediator: mediator)
        )
    }

    private func buildArray(
        typeName: String,
        value: TypeMetadata.Def.Array,
        mediator: TypeRegistering
    ) throws -> Node {
        try FixedArrayNode(
            typeName: typeName,
            elementType: underlyingNode(for: value.type, mediator: mediator),
            length: UInt64(value.length)
        )
    }

    private func buildTuple(
        typeName: String,
        value: [BigUInt],
        mediator: TypeRegistering
    ) throws -> Node {
        if value.count == 1 {
            // return ProxyNode for this type
            let underlyingNode = try underlyingNode(for: value[0], mediator: mediator)
            return AliasNode(
                typeName: typeName,
                underlyingTypeName: underlyingNode.typeName
            )
        }

        let innerNodes = try value.map {
            try underlyingNode(for: $0, mediator: mediator)
        }

        return TupleNode(typeName: typeName, innerNodes: innerNodes)
    }

    private func buildPrimitive(
        typeName _: String,
        value: TypeMetadata.Def.Primitive,
        mediator _: TypeRegistering
    ) throws -> Node? {
        // Some types like char not yet supported, nor presented in actual runtimes
        switch value {
        case .bool:
            return BoolNode()
        case .char:
            assertionFailure()
            return nil
        case .string:
            return StringNode()
        case .u8:
            return U8Node()
        case .u16:
            return U16Node()
        case .u32:
            return U32Node()
        case .u64:
            return U64Node()
        case .u128:
            return U128Node()
        case .u256:
            return U256Node()
        case .i8:
            return I8Node()
        case .i16:
            return I16Node()
        case .i32:
            return I32Node()
        case .i64:
            return I64Node()
        case .i128:
            return I128Node()
        case .i256:
            return I256Node()
        }
    }

    private func buildCompact(
        typeName: String,
        value: TypeMetadata.Def.Compact,
        mediator: TypeRegistering
    ) throws -> Node {
        try CompactNode(
            typeName: typeName,
            underlying: underlyingNode(for: value.type, mediator: mediator)
        )
    }

    private func buildBitSequence(
        typeName _: String,
        value _: TypeMetadata.Def.BitSequence,
        mediator _: TypeRegistering
    ) throws -> Node {
        // Might be failing, as BitVecNode supports static types
        BitVecNode()
    }

    // MARK: - Underlying node

    private func underlyingNode(for type: BigUInt, mediator: TypeRegistering) throws -> Node {
        let typeName = try schemaResolver.typeName(for: type)
        return mediator.register(typeName: typeName, json: .typeId(type))
    }
}
