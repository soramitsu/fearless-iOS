import Foundation
import SSFUtils

enum RuntimeHelperError: Error {
    case invalidCatalogBaseName
    case invalidCatalogNetworkName
    case invalidCatalogMetadataName
}

final class RuntimeHelper {
    static func createRuntimeMetadata(_ name: String) throws -> RuntimeMetadata {
        guard let metadataUrl = Bundle(for: self).url(forResource: name, withExtension: "") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let expectedData = try Data(hexStringSSF: hex)

        let decoder = try ScaleDecoder(data: expectedData)
        return try RuntimeMetadata(scaleDecoder: decoder)
    }

    static func createTypeRegistry(from name: String, runtimeMetadataName: String) throws
        -> TypeRegistry
    {
        guard let url = Bundle(for: self).url(forResource: name, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        let runtimeMetadata = try Self.createRuntimeMetadata(runtimeMetadataName)

        let data = try Data(contentsOf: url)
        let basisNodes = BasisNodes.allNodes(for: runtimeMetadata)
        let registry = try TypeRegistry.createFromTypesDefinition(
            data: data,
            additionalNodes: basisNodes,
            schemaResolver: runtimeMetadata.schemaResolver
        )

        return registry
    }

    static func createTypeRegistryCatalog(
        from baseName: String,
        networkName: String,
        runtimeMetadataName: String,
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalog {
        let runtimeMetadata = try Self.createRuntimeMetadata(runtimeMetadataName)

        return try createTypeRegistryCatalog(
            from: baseName,
            networkName: networkName,
            runtimeMetadata: runtimeMetadata,
            usedRuntimePaths: usedRuntimePaths
        )
    }

    static func createTypeRegistryCatalog(
        from baseName: String,
        runtimeMetadataName: String,
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalog {
        let runtimeMetadata = try Self.createRuntimeMetadata(runtimeMetadataName)

        return try createTypeRegistryCatalog(
            from: baseName,
            runtimeMetadata: runtimeMetadata,
            usedRuntimePaths: usedRuntimePaths
        )
    }

    static func createTypeRegistryCatalog(
        from baseName: String,
        networkName: String,
        runtimeMetadata: RuntimeMetadata,
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalog {
        guard let baseUrl = Bundle(for: self).url(forResource: baseName, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        guard let networkUrl = Bundle(for: self)
            .url(forResource: networkName, withExtension: "json") else
        {
            throw RuntimeHelperError.invalidCatalogNetworkName
        }

        let baseData = try Data(contentsOf: baseUrl)
        let networdData = try Data(contentsOf: networkUrl)

        let registry = try TypeRegistryCatalog.createFromTypeDefinition(
            baseData,
            versioningData: networdData,
            runtimeMetadata: runtimeMetadata,
            usedRuntimePaths: usedRuntimePaths
        )

        return registry
    }

    static func createTypeRegistryCatalog(
        from baseName: String,
        runtimeMetadata: RuntimeMetadata,
        usedRuntimePaths: [String: [String]]
    ) throws -> TypeRegistryCatalog {
        guard let baseUrl = Bundle(for: self).url(forResource: baseName, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        let typesData = try Data(contentsOf: baseUrl)

        let registry = try TypeRegistryCatalog.createFromTypeDefinition(
            typesData,
            runtimeMetadata: runtimeMetadata,
            usedRuntimePaths: usedRuntimePaths
        )

        return registry
    }

    static func dummyRuntimeMetadata() throws -> RuntimeMetadata {
        try RuntimeMetadata.v1(
            modules: [
                RuntimeMetadataV1.ModuleMetadata(
                    name: "A",
                    storage: RuntimeMetadataV1.StorageMetadata(prefix: "_A", entries: []),
                    calls: [
                        RuntimeMetadataV1.FunctionMetadata(
                            name: "B",
                            arguments: [
                                RuntimeMetadataV1.FunctionArgumentMetadata(
                                    name: "arg1",
                                    type: "bool"
                                ),
                                RuntimeMetadataV1.FunctionArgumentMetadata(
                                    name: "arg2",
                                    type: "u8"
                                ),
                            ],
                            documentation: []
                        ),
                    ],
                    events: [
                        RuntimeMetadataV1.EventMetadata(
                            name: "A",
                            arguments: ["bool", "u8"],
                            documentation: []
                        ),
                    ],
                    constants: [],
                    errors: [],
                    index: 1
                ),
            ],
            extrinsic: RuntimeMetadataV1.ExtrinsicMetadata(version: 1, signedExtensions: [])
        )
    }
}
