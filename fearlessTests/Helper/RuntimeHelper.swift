import Foundation
import SSFUtils
import BigInt
@testable import fearless

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
        let registry = try TypeRegistry.createFromTypesDefinition(
            data: data,
            additionalNodes: basisNodes,
            schemaResolver: runtimeMetadata.schemaResolver
        )

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
        let networkData = try Data(contentsOf: networkUrl)
        
        var usedRuntimePaths = UsedRuntimePaths()

        let registry = try TypeRegistryCatalog.createFromTypeDefinition(
            baseData,
            versioningData: networkData,
            runtimeMetadata: runtimeMetadata,
            usedRuntimePaths: usedRuntimePaths.usedRuntimePaths
        )

        return registry
    }

    static var dummyRuntimeMetadata: RuntimeMetadata {
        get throws {
            return try RuntimeMetadata.v14(
                types: [],
                modules: [RuntimeMetadataV14.ModuleMetadata(
                    name: "A",
                    storage: nil,
                    callsIndex: nil,
                    eventsIndex: nil,
                    constants: [],
                    errorsIndex: nil,
                    index: 1
                )],
                extrinsic: RuntimeMetadataV14.ExtrinsicMetadata(
                    type: 0,
                    version: 1,
                    signedExtensions: []
                )
            )
        }
    }
}
