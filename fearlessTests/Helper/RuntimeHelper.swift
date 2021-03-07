import Foundation
import FearlessUtils

enum RuntimeHelperError: Error {
    case invalidCatalogBaseName
    case invalidCatalogNetworkName
    case invalidCatalogMetadataName
}

final class RuntimeHelper {
    static func createRuntimeMetadata(_ name: String) throws -> RuntimeMetadata {
        guard let metadataUrl = Bundle(for: self).url(forResource: name,
                                                      withExtension: "") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let expectedData = try Data(hexString: hex)

        let decoder = try ScaleDecoder(data: expectedData)
        return try RuntimeMetadata(scaleDecoder: decoder)
    }

    static func createTypeRegistry(from name: String, runtimeMetadataName: String) throws
    -> TypeRegistry {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        let runtimeMetadata = try Self.createRuntimeMetadata(runtimeMetadataName)

        let data = try Data(contentsOf: url)
        let basisNodes = BasisNodes.allNodes(for: runtimeMetadata)
        let registry = try TypeRegistry
            .createFromTypesDefinition(data: data,
                                       additionalNodes: basisNodes)

        return registry
    }

    static func createTypeRegistryCatalog(from baseName: String,
                                          networkName: String,
                                          runtimeMetadataName: String)
    throws -> TypeRegistryCatalog {
        let runtimeMetadata = try Self.createRuntimeMetadata(runtimeMetadataName)

        return try createTypeRegistryCatalog(from: baseName,
                                             networkName: networkName,
                                             runtimeMetadata: runtimeMetadata)
    }

    static func createTypeRegistryCatalog(from baseName: String,
                                          networkName: String,
                                          runtimeMetadata: RuntimeMetadata)
    throws -> TypeRegistryCatalog {
        guard let baseUrl = Bundle.main.url(forResource: baseName, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        guard let networkUrl = Bundle.main.url(forResource: networkName,
                                               withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogNetworkName
        }

        let baseData = try Data(contentsOf: baseUrl)
        let networdData = try Data(contentsOf: networkUrl)

        let registry = try TypeRegistryCatalog
            .createFromBaseTypeDefinition(baseData,
                                          networkDefinitionData: networdData,
                                          runtimeMetadata: runtimeMetadata)

        return registry
    }

    static let dummyRuntimeMetadata: RuntimeMetadata = {
        RuntimeMetadata(metaReserved: 1,
                        runtimeMetadataVersion: 1,
                        modules: [
                            ModuleMetadata(name: "A",
                                           storage: StorageMetadata(prefix: "_A", entries: []),
                                           calls: [
                                            FunctionMetadata(name: "B",
                                                             arguments: [
                                                                FunctionArgumentMetadata(name: "arg1", type: "bool"),
                                                                FunctionArgumentMetadata(name: "arg2", type: "u8")
                                                             ], documentation: [])
                                           ],
                                           events: [
                                            EventMetadata(name: "A",
                                                          arguments: ["bool", "u8"],
                                                          documentation: [])
                                           ],
                                           constants: [],
                                           errors: [],
                                           index: 1)
                        ],
                        extrinsic: ExtrinsicMetadata(version: 1,
                                                     signedExtensions: []))
    }()
}
