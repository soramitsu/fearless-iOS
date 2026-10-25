import SSFModels
import XCTest

@testable import SSFXCM

final class XcmChainsConfigFetcherTests: XCTestCase {
    var fetcher: XcmChainsConfigFetcher?
    var chainRegistry: ChainRegistryProtocolMock?

    override func setUp() {
        super.setUp()

        let chainRegistry = ChainRegistryProtocolMock()
        chainRegistry.getChainsReturnValue = [
            TestData.firstChain,
            TestData.secondChain,
            TestData.errorChain,
        ]

        self.chainRegistry = chainRegistry
        fetcher = XcmChainsConfigFetcher(chainRegistry: chainRegistry)
    }

    override func tearDown() {
        super.tearDown()
        chainRegistry = nil
        fetcher = nil
    }

    func testGetAvailableOriginalChains() async throws {
        // arrange
        let assetSymbol = "xc0"
        let destinationChainId: ChainModel.Id = "1"

        // act
        let chainIds = try await fetcher?.getAvailableOriginalChains(
            assetSymbol: assetSymbol,
            destinationChainId: destinationChainId
        )

        // assert
        XCTAssertNotNil(chainIds)
        XCTAssertEqual(chainIds?.count, 1)
        XCTAssertEqual(chainIds?.first, TestData.secondChain.chainId)
    }

    func testGetAvailableOriginalChainsWithError() async throws {
        // arrange
        let assetSymbol = "xc0"
        let destinationChainId: ChainModel.Id = "1"
        chainRegistry?.getChainForThrowableError = XcmError.missingRemoteChainsResult

        // act
        do {
            try await fetcher?.getAvailableOriginalChains(
                assetSymbol: assetSymbol,
                destinationChainId: destinationChainId
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingRemoteChainsResult.localizedDescription
            )
        }
    }

    func testGetAvailableAssets() async throws {
        // arrange
        let originalChainID: ChainModel.Id = "0"
        let destinationChainId: ChainModel.Id = "1"

        // act
        let assets = try await fetcher?.getAvailableAssets(
            originalChainId: originalChainID,
            destinationChainId: destinationChainId
        )

        // assert
        XCTAssertNotNil(assets)
        XCTAssertEqual(assets?.count, 1)
        XCTAssertEqual(assets?.first, TestData.secondChain.xcm?.availableAssets.first?.symbol)
    }

    func testGetAvailableAssetsWithError() async throws {
        // arrange
        let originalChainID: ChainModel.Id = "0"
        let destinationChainId: ChainModel.Id = "1"
        chainRegistry?.getChainForThrowableError = XcmError.missingRemoteChainsResult

        // act
        do {
            try await fetcher?.getAvailableAssets(
                originalChainId: originalChainID,
                destinationChainId: destinationChainId
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingRemoteChainsResult.localizedDescription
            )
        }
    }

    func testGetAvailableDestinationChains() async throws {
        // arrange
        let originalChainId: ChainModel.Id = "0"
        let assetSymbol = "xc1"

        // act
        let chainIds = try await fetcher?.getAvailableDestinationChains(
            originalChainId: originalChainId,
            assetSymbol: assetSymbol
        )

        // assert
        XCTAssertNotNil(chainIds)
        XCTAssertEqual(chainIds?.count, 1)
        XCTAssertEqual(chainIds?.first, TestData.firstChain.chainId)
    }

    func testGetAvailableDestinationChainsWithError() async throws {
        // arrange
        let originalChainId: ChainModel.Id = "0"
        let assetSymbol = "xc1"
        chainRegistry?.getChainForThrowableError = XcmError.missingRemoteChainsResult

        // act
        do {
            try await fetcher?.getAvailableDestinationChains(
                originalChainId: originalChainId,
                assetSymbol: assetSymbol
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingRemoteChainsResult.localizedDescription
            )
        }
    }

    func testGetVersion() async throws {
        // arrange
        let chainId: ChainModel.Id = TestData.firstChain.chainId

        // act
        let version = try await fetcher?.getVersion(for: chainId)

        // assert
        XCTAssertNotNil(version)
        XCTAssertEqual(version, .V3)
    }

    func testGetVersionWithError() async throws {
        // arrange
        let chainId: ChainModel.Id = TestData.errorChain.chainId

        // act
        do {
            try await fetcher?.getVersion(for: chainId)
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingRemoteXcmVersion.localizedDescription
            )
        }
    }
}

extension XcmChainsConfigFetcherTests {
    enum TestData {
        static let firstChain = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "0",
            paraId: "1001",
            name: "test1",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: true,
                availableAssets: [.init(
                    id: "0",
                    symbol: "0"
                )],
                availableDestinations: [.init(
                    chainId: "0",
                    bridgeParachainId: "2",
                    assets: [.init(
                        id: "1",
                        symbol: "1"
                    )]
                )]
            ),
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "test1",
                apikey: nil
            )]),
            addressPrefix: 0,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        static let secondChain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: "1",
            paraId: "1002",
            name: "test2",
            xcm: XcmChain(
                xcmVersion: .V1,
                destWeightIsPrimitive: true,
                availableAssets: [.init(
                    id: "1",
                    symbol: "1"
                )],
                availableDestinations: [.init(
                    chainId: "1",
                    bridgeParachainId: "2",
                    assets: [.init(id: "0", symbol: "0")]
                )]
            ),
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "test2",
                apikey: nil
            )]),
            addressPrefix: 1,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        static let errorChain = ChainModel(
            rank: 2,
            disabled: false,
            chainId: "2",
            paraId: "1",
            name: "test3",
            xcm: nil,
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "test3",
                apikey: nil
            )]),
            addressPrefix: 2,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
