import SSFModels
import XCTest

@testable import SSFXCM

final class XcmDestinationTests: XCTestCase {
    func testDetermineChainType() throws {
        // act
        let chainType = try XcmChainType.determineChainType(for: TestData.chain)

        // assert
        XCTAssertEqual(chainType.hashValue, XcmChainType.nativeParachain.hashValue)
    }

    func testDetermineChainTypeWithError() throws {
        // act
        XCTAssertThrowsError(
            try XcmChainType
                .determineChainType(for: TestData.errorChain)
        ) { error in
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.invalidParachainRange.localizedDescription
            )
        }
    }
}

extension XcmDestinationTests {
    enum TestData {
        static let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test")
            .appendingPathExtension("json")

        static let chain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: "1",
            paraId: "1001",
            name: "test",
            xcm: nil,
            nodes: Set([ChainNodeModel(url: TestData.url, name: "test", apikey: nil)]),
            addressPrefix: 1,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        static let errorChain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: "1",
            paraId: "1",
            name: "test",
            xcm: nil,
            nodes: Set([ChainNodeModel(
                url: TestData.url,
                name: "test",
                apikey: nil
            )]),
            addressPrefix: 1,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
