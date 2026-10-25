import Foundation

public extension TypeRegistryCatalog {
    static func createFromTypeDefinition(
        _ definitionData: Data,
        versioningData: Data,
        runtimeMetadata: RuntimeMetadata,
        customNodes: [Node] = [],
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalog {
        let versionedJsons = try prepareVersionedJsons(from: versioningData)

        return try createFromTypeDefinition(
            definitionData,
            versionedJsons: versionedJsons,
            runtimeMetadata: runtimeMetadata,
            customNodes: customNodes,
            usedRuntimePaths: usedRuntimePaths
        )
    }

    static func createFromTypeDefinition(
        _ definitionData: Data,
        runtimeMetadata: RuntimeMetadata,
        customNodes: [Node] = [],
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalog {
        try createFromTypeDefinition(
            definitionData,
            versionedJsons: [:],
            runtimeMetadata: runtimeMetadata,
            customNodes: customNodes,
            usedRuntimePaths: usedRuntimePaths
        )
    }

    static func createFromTypeDefinition(
        _ definitionData: Data,
        versionedJsons: [UInt64: JSON],
        runtimeMetadata: RuntimeMetadata,
        customNodes: [Node] = [],
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalog {
        let additonalNodes = BasisNodes.allNodes(for: runtimeMetadata) + customNodes
        let baseRegistry = try TypeRegistry.createFromTypesDefinition(
            data: definitionData,
            additionalNodes: additonalNodes,
            schemaResolver: runtimeMetadata.schemaResolver
        )

        let versionedRegistries = try versionedJsons.mapValues {
            try TypeRegistry.createFromTypesDefinition(
                json: $0,
                additionalNodes: [],
                schemaResolver: runtimeMetadata.schemaResolver
            )
        }

        let typeResolver = OneOfTypeResolver(children: [
            RuntimeSchemaResolver(schemaResolver: runtimeMetadata.schemaResolver),
            CaseInsensitiveResolver(),
            TableResolver.noise(),
            RegexReplaceResolver.noise(),
            RegexReplaceResolver.genericsFilter(),
        ])

        let runtimeMetadataRegistry = try TypeRegistry.createFromRuntimeMetadata(
            runtimeMetadata,
            additionalTypes: RuntimeTypes.known,
            usedRuntimePaths: usedRuntimePaths
        )

        return TypeRegistryCatalog(
            baseRegistry: baseRegistry,
            versionedRegistries: versionedRegistries,
            runtimeMetadataRegistry: runtimeMetadataRegistry,
            typeResolver: typeResolver
        )
    }

    private static func prepareVersionedJsons(from data: Data) throws -> [UInt64: JSON] {
        let versionedDefinitionJson = try JSONDecoder().decode(JSON.self, from: data)

        guard let versioning = versionedDefinitionJson.versioning?.arrayValue else {
            throw TypeRegistryCatalogError.missingVersioning
        }

        guard let currentVersion = versionedDefinitionJson.runtime_id?.unsignedIntValue else {
            throw TypeRegistryCatalogError.missingCurrentVersion
        }

        guard let types = versionedDefinitionJson.types else {
            throw TypeRegistryCatalogError.missingNetworkTypes
        }

        let typeKey = "types"
        let overridesKey = "overrides"

        var currentVersionDict = [typeKey: types]
        if let overrides = versionedDefinitionJson.overrides {
            currentVersionDict[overridesKey] = overrides
        }

        let initDict = [currentVersion: JSON.dictionaryValue(currentVersionDict)]

        return versioning.reduce(into: initDict) { result, versionedJson in
            guard let version = versionedJson.runtime_range?.arrayValue?.first?.unsignedIntValue,
                  let definitionDic = versionedJson.types?.dictValue else
            {
                return
            }

            if let oldDefinitionDic = result[version]?.types?.dictValue {
                let mapping = oldDefinitionDic.merging(definitionDic) { v1, _ in v1 }
                result[version] = .dictionaryValue([typeKey: .dictionaryValue(mapping)])
            } else {
                result[version] = .dictionaryValue([typeKey: .dictionaryValue(definitionDic)])
            }
        }
    }
}
