import XCTest
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class AssetHubRuntimeProviderTests: XCTestCase {
    func testFallbackIsLimitedToKnownHubGenesisAndPreservesSuppliedDefinitions() throws {
        let custom = Data("custom definitions must remain byte-identical".utf8)
        for route in AssetHubStakingRoute.routes {
            let fallback = try XCTUnwrap(AssetHubStakingRoute.runtimeTypes(for: route.stakingChainId, existing: nil))
            XCTAssertEqual(AssetHubStakingRoute.runtimeTypes(for: route.stakingChainId, existing: fallback), fallback)
            XCTAssertEqual(AssetHubStakingRoute.runtimeTypes(for: route.stakingChainId, existing: custom), custom)
            XCTAssertNil(AssetHubStakingRoute.runtimeTypes(for: route.relayChainId, existing: nil))
        }
        XCTAssertNil(AssetHubStakingRoute.runtimeTypes(for: "unrelated", existing: nil))
        XCTAssertEqual(AssetHubStakingRoute.runtimeTypes(for: "unrelated", existing: custom), custom)
    }

    func testColdWestendProviderBuildsNativeSnapshotWithoutCatalogueTypesAndRetainsMetadata() async throws {
        let runtime = try AssetHubRuntimeFixture(name: "westend")
        let repository = AnyDataProviderRepository(CrossChainRuntimeRepository())
        let factory = RuntimeSnapshotFactory(chainId: runtime.chainId, filesOperationFactory: RuntimeFilesOperationFactoryProtocolStub(), repository: repository)
        let provider = fearless.RuntimeProvider(
            chainModel: AssetHubTestSupport.makeAsset(chainId: runtime.chainId).chain,
            snapshotOperationFactory: factory, snapshotHotOperationFactory: nil,
            eventCenter: EventCenter(), operationQueue: OperationQueue(), repository: repository,
            usedRuntimePaths: [:], chainMetadata: nil, chainTypes: nil
        )
        provider.setup()
        XCTAssertNil(provider.snapshot)
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "asset-hub-westend-metadata-v14", withExtension: ""))
        let bytes = try Data(hexStringSSF: String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines))
        let item = fearless.RuntimeMetadataItem(chain: runtime.chainId, version: runtime.factory.specVersion, txVersion: runtime.factory.txVersion, metadata: bytes)
        provider.processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted(chainId: runtime.chainId, version: RuntimeVersion(specVersion: item.version, transactionVersion: item.txVersion), metadata: item))
        let coder = try await provider.fetchCoderFactory()
        XCTAssertEqual(coder.specVersion, runtime.factory.specVersion)
        XCTAssertNotNil(coder.metadata.getStorageMetadata(for: .activeEra))
        let snapshot = try await provider.readySnapshot()
        XCTAssertEqual(snapshot.specVersion, runtime.factory.specVersion)
        let call = SubstrateCallFactoryDefault(runtimeService: provider).chill()
        let encoder = coder.createEncoder()
        try encoder.append(json: call.toScaleCompatibleJSON(), type: GenericType.call.name)
        XCTAssertFalse(try encoder.encode().isEmpty)
        provider.cleanup()
    }

    func testMetadataArrivingBeforeLegacyTypesIsRetainedForLaterCatalogueDelivery() async throws {
        let runtime = try AssetHubRuntimeFixture(name: "westend")
        let chainId = "legacy-not-fallback"
        let repository = AnyDataProviderRepository(CrossChainRuntimeRepository())
        let factory = RuntimeSnapshotFactory(chainId: chainId, filesOperationFactory: RuntimeFilesOperationFactoryProtocolStub(), repository: repository)
        let provider = fearless.RuntimeProvider(
            chainModel: AssetHubTestSupport.makeAsset(chainId: chainId).chain,
            snapshotOperationFactory: factory,
            snapshotHotOperationFactory: nil,
            eventCenter: EventCenter(),
            operationQueue: OperationQueue(),
            repository: repository,
            usedRuntimePaths: [:],
            chainMetadata: nil,
            chainTypes: nil
        )
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "asset-hub-westend-metadata-v14", withExtension: ""))
        let item = fearless.RuntimeMetadataItem(chain: chainId, version: runtime.factory.specVersion, txVersion: runtime.factory.txVersion, metadata: try Data(hexStringSSF: String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)))
        provider.processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted(chainId: chainId, version: RuntimeVersion(specVersion: item.version, transactionVersion: item.txVersion), metadata: item))
        XCTAssertNil(provider.snapshot)
        let types = try XCTUnwrap(AssetHubStakingRoute.runtimeTypes(for: runtime.chainId, existing: nil))
        provider.processRuntimeChainsTypesSyncCompleted(event: RuntimeChainsTypesSyncCompleted(versioningMap: [chainId: types]))
        let coder = try await provider.fetchCoderFactory()
        XCTAssertEqual(coder.specVersion, item.version)
        provider.cleanup()
    }
}
