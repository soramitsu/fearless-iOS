import Foundation
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
import RobinHood
@testable import fearless

final class AssetHubRuntimeFixture: RuntimeProviderProtocol, StakingRuntimeIdentifying {
    let chainId: String
    let factory: RuntimeCoderFactoryProtocol
    let snapshot: RuntimeSnapshot?
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion

    init(name: String, modifyingExtensions: (([RuntimeMetadataV14.ExtrinsicMetadata.SignedExtension]) -> [RuntimeMetadataV14.ExtrinsicMetadata.SignedExtension])? = nil, versioningData: Data? = nil) throws {
        let index = ["polkadot": 0, "kusama": 1, "westend": 2][name]!
        chainId = AssetHubStakingRoute.routes[index].stakingChainId
        let spec: UInt32 = [2_005_001, 2_003_002, 1_025_002][index]
        let tx: UInt32 = [15, 15, 16][index]
        let original = try RuntimeHelper.createRuntimeMetadata("asset-hub-\(name)-metadata-v14")
        let metadata: RuntimeMetadata
        if let modifyingExtensions = modifyingExtensions, let extrinsic = original.extrinsic as? RuntimeMetadataV14.ExtrinsicMetadata,
           let schema = original.schema, let type = extrinsic.type {
            metadata = try RuntimeMetadata.v14(types: schema.types, modules: original.modules.compactMap { $0 as? RuntimeMetadataV14.ModuleMetadata }, extrinsic: .init(type: type, version: extrinsic.version, signedExtensions: modifyingExtensions(extrinsic.signedExtensions)))
        } else { metadata = original }
        let definition = Data("{\"types\":{\"Index\":\"u32\",\"Balance\":\"u128\"}}".utf8)
        let catalog: TypeRegistryCatalog
        if let versioningData = versioningData {
            catalog = try TypeRegistryCatalog.createFromTypeDefinition(definition, versioningData: versioningData, runtimeMetadata: metadata, usedRuntimePaths: [:])
        } else {
            catalog = try TypeRegistryCatalog.createFromTypeDefinition(definition, runtimeMetadata: metadata, usedRuntimePaths: [:])
        }
        factory = TestRuntimeCoderFactory(catalog: catalog, specVersion: spec, txVersion: tx, metadata: metadata)
        snapshot = RuntimeSnapshot(typeRegistryCatalog: catalog, specVersion: spec, txVersion: tx, metadata: metadata)
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { snapshot! }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { factory }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { self.factory } }
}
