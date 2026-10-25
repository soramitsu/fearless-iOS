import Foundation

public extension TypeRegistry {
    static func createFromTypesDefinition(
        data: Data,
        additionalNodes: [Node],
        schemaResolver: Schema.Resolver
    ) throws -> TypeRegistry {
        let jsonDecoder = JSONDecoder()
        let json = try jsonDecoder.decode(JSON.self, from: data)

        return try createFromTypesDefinition(
            json: json,
            additionalNodes: additionalNodes,
            schemaResolver: schemaResolver
        )
    }

    static func createFromTypesDefinition(
        json: JSON,
        additionalNodes: [Node],
        schemaResolver: Schema.Resolver
    ) throws -> TypeRegistry {
        guard let types = json.types else {
            throw TypeRegistryError.unexpectedJson
        }

        let factories: [TypeNodeFactoryProtocol] = [
            RuntimeSchemaNodeFactory(schemaResolver: schemaResolver),
            StructNodeFactory(parser: TypeMappingParser.structure()),
            EnumNodeFactory(parser: TypeMappingParser.enumeration()),
            EnumValuesNodeFactory(parser: TypeValuesParser.enumeration()),
            NumericSetNodeFactory(parser: TypeSetParser.generic()),
            TupleNodeFactory(parser: ComponentsParser.tuple()),
            FixedArrayNodeFactory(parser: FixedArrayParser.generic()),
            VectorNodeFactory(parser: RegexParser.vector()),
            OptionNodeFactory(parser: RegexParser.option()),
            CompactNodeFactory(parser: RegexParser.compact()),
            AliasNodeFactory(parser: TermParser.generic()),
        ]

        let resolvers: [TypeResolving] = [
            RuntimeSchemaResolver(schemaResolver: schemaResolver),
            CaseInsensitiveResolver(),
            TableResolver.noise(),
            RegexReplaceResolver.noise(),
            RegexReplaceResolver.genericsFilter(),
        ]

        return try TypeRegistry(
            json: types,
            overrides: json["overrides"]?.arrayValue,
            nodeFactory: OneOfTypeNodeFactory(children: factories),
            typeResolver: OneOfTypeResolver(children: resolvers),
            additionalNodes: additionalNodes
        )
    }
}
