import BigInt
import SSFChainRegistry
import SSFNetwork
import SSFRuntimeCodingService
import SSFSigner
import SSFUtils
import XCTest

@testable import SSFXCM

final class CallPathDeterminerTests: XCTestCase {
    var determiner: CallPathDeterminer?
    var chainRegistry: ChainRegistryProtocolMock?

    override func setUp() {
        super.setUp()
        let chainRegistry = ChainRegistryProtocolMock()
        let determiner: CallPathDeterminer = CallPathDeterminerImpl(
            chainRegistry: chainRegistry,
            fromChainData: TestData.fromChainData
        )

        self.chainRegistry = chainRegistry
        self.determiner = determiner
    }

    override func tearDown() {
        super.tearDown()
        chainRegistry = nil
        determiner = nil
    }

    func testCallPathDeterminerInit() {
        // arrange
        let chainRegistry = ChainRegistryProtocolMock()

        // act
        let pathDeterminer = CallPathDeterminerImpl(
            chainRegistry: chainRegistry,
            fromChainData: TestData.fromChainData
        )

        // assert
        XCTAssertNotNil(pathDeterminer)
    }

    func testDetermineCallPath() async throws {
        // act
        let callPath = try await determiner?.determineCallPath(
            from: .relaychain,
            dest: .nativeParachain
        )

        // assert
        XCTAssertEqual(callPath, .xcmPalletLimitedTeleportAssets)
    }

    func testTeleportsBetweenTheRelayChainAndSystemParachains() async throws {
        let teleports: [(XcmChainType, XcmChainType, XcmCallPath)] = [
            (.relaychain, .nativeParachain, .xcmPalletLimitedTeleportAssets),
            (.nativeParachain, .relaychain, .polkadotXcmLimitedTeleportAssets),
            (.nativeParachain, .nativeParachain, .polkadotXcmLimitedTeleportAssets),
            (.nativeParachain, .parachain, .polkadotXcmLimitedReserveTransferAssets),
        ]

        for (from, dest, expected) in teleports {
            let callPath = try await determiner?.determineCallPath(from: from, dest: dest)
            XCTAssertEqual(callPath, expected, "\(from) -> \(dest)")
        }
    }

    func testReserveTransfersThroughTheRelayChainAreRefused() async throws {
        // Since the Asset Hub migration the relay chains reject reserve transfers of their token.
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot(with: "xTokens")

        for (from, dest) in [
            (XcmChainType.relaychain, XcmChainType.parachain),
            (.relaychain, .soraMainnet),
            (.parachain, .relaychain),
        ] {
            await assertDirectionNotSupported(from: from, dest: dest)
        }
    }

    func testDetermineCallPathWithFunctionCall() async throws {
        // arrange
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot()

        // act
        let callPath = try await determiner?.determineCallPath(
            from: .parachain,
            dest: .parachain
        )

        // assert
        XCTAssertEqual(callPath, .polkadotXcmLimitedReserveTransferAssets)
    }

    func testAParachainOnPolkadotXcmSendsToAssetHubByReserveTransfer() async throws {
        // A parachain is no trusted teleporter of the system parachains.
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot()

        let callPath = try await determiner?.determineCallPath(
            from: .parachain,
            dest: .nativeParachain
        )

        XCTAssertEqual(callPath, .polkadotXcmLimitedReserveTransferAssets)
    }

    func testAParachainOnXTokensUsesTransferMultiasset() async throws {
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot(with: "xTokens")

        for dest in [XcmChainType.nativeParachain, .parachain, .soraMainnet] {
            let callPath = try await determiner?.determineCallPath(from: .parachain, dest: dest)
            XCTAssertEqual(callPath, .xTokensTransferMultiasset, "\(dest)")
        }
    }

    func testAParachainOnPolkadotXcmHasNoCallToReachARelayChain() async throws {
        // arrange
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot()

        // act, assert
        await assertDirectionNotSupported(from: .parachain, dest: .relaychain)
    }

    func testSoraBridgeDirections() async throws {
        let bridges: [(XcmChainType, XcmChainType, XcmCallPath)] = [
            (.soraMainnet, .relaychain, .bridgeProxyBurn),
            (.soraMainnet, .parachain, .bridgeProxyBurn),
            (.soraMainnet, .liberland, .bridgeProxyBurn),
            (.liberland, .soraMainnet, .soraBridgeAppBurn),
        ]

        for (from, dest, expected) in bridges {
            let callPath = try await determiner?.determineCallPath(from: from, dest: dest)
            XCTAssertEqual(callPath, expected, "\(from) -> \(dest)")
        }
    }

    func testDetermineCallPathWithDirectionError() async throws {
        await assertDirectionNotSupported(from: .relaychain, dest: .relaychain)
    }

    func testDetermineCallPathWithPalletError() async throws {
        // arrange
        chainRegistry?
            .getReadySnapshotChainIdUsedRuntimePathsRuntimeItemReturnValue =
            try createRuntimeSnapshot(with: "")

        // act
        do {
            let callPath = try await determiner?.determineCallPath(
                from: .parachain,
                dest: .parachain
            )
            XCTFail("Expected no call path, got \(String(describing: callPath))")
        } catch {
            // assert
            XCTAssertEqual(
                "\(error)",
                "\(XcmError.noXcmPallet(chainId: TestData.fromChainData.chainId))"
            )
        }
    }

    private func assertDirectionNotSupported(
        from: XcmChainType,
        dest: XcmChainType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            let callPath = try await determiner?.determineCallPath(from: from, dest: dest)
            XCTFail(
                "Expected no call path for \(from) -> \(dest), got \(String(describing: callPath))",
                file: file,
                line: line
            )
        } catch {
            XCTAssertEqual(
                "\(error)",
                "\(XcmError.directionNotSupported)",
                "\(from) -> \(dest)",
                file: file,
                line: line
            )
        }
    }
}

extension CallPathDeterminerTests {
    enum TestData {
        static let fromChainData = XcmAssembly.FromChainData(
            chainId: "1",
            cryptoType: .ed25519,
            chainMetadata: nil,
            accountId: Data(),
            chainType: .substrate
        )
    }

    private func createRuntimeSnapshot(with moduleName: String = "polkadotXcm") throws
        -> RuntimeSnapshot
    {
        let module = RuntimeMetadataV14.ModuleMetadata(
            name: moduleName,
            storage: nil,
            callsIndex: BigUInt(),
            eventsIndex: BigUInt(),
            constants: [],
            errorsIndex: BigUInt(),
            index: 0
        )

        let extrinsic = RuntimeMetadataV1.ExtrinsicMetadata(version: 0, signedExtensions: [])

        let wrappedMetadata = RuntimeMetadataProtocolMock(
            schema: nil,
            modules: [module],
            extrinsic: extrinsic
        )

        let metadata = try RuntimeMetadata(
            wrapping: wrappedMetadata,
            metaReserved: 0,
            version: 0
        )

        let typeRegistry = TypeRegistryProtocolMock()

        let registry = TypeRegistryCatalog(
            baseRegistry: typeRegistry,
            versionedRegistries: [:],
            runtimeMetadataRegistry: typeRegistry,
            typeResolver: CaseInsensitiveResolver()
        )

        let snapshot = RuntimeSnapshot(
            typeRegistryCatalog: registry,
            specVersion: 0,
            txVersion: 0,
            metadata: metadata
        )

        return snapshot
    }
}
