import XCTest

@testable import SSFXCM

/// Defaults address the app-owned configuration. `chains/v2` remains the newest
/// chain list that this lower-level model decodes without the app adapter.
final class XcmConfigTests: XCTestCase {
    var config: XcmConfigProtocol?

    override func setUp() {
        super.setUp()
        config = XcmConfig.shared
    }

    override func tearDown() {
        super.tearDown()
        config = nil
    }

    func testChainsSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.masterBranchString + TestData
            .chainUrlString

        // act
        let url = config?.chainsSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }

    func testChainTypesSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.masterBranchString + TestData
            .typeUrlString

        // act
        let url = config?.chainTypesSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }

    func testDestinationFeeSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.masterBranchString + TestData
            .destinationUrlString

        // act
        let url = config?.destinationFeeSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }

    func testTokenLocationsSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.masterBranchString + TestData
            .tokenUrlString

        // act
        let url = config?.tokenLocationsSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }

    func testNoDefaultPointsAtTheRemovedRococoBranch() {
        let urls = [
            config?.chainsSourceUrl,
            config?.chainTypesSourceUrl,
            config?.destinationFeeSourceUrl,
            config?.tokenLocationsSourceUrl,
        ].compactMap { $0?.absoluteString }

        XCTAssertEqual(urls.count, 4)
        XCTAssertTrue(urls.allSatisfy { !$0.contains("feature/rococo") }, "\(urls)")
    }
}

private extension XcmConfigTests {
    private enum TestData {
        static let baseUrlString =
            "https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/"
        static let masterBranchString = "production/"
        static let chainUrlString = "chains/v2/chains.json"
        static let typeUrlString = "chains/all_chains_types.json"
        static let destinationUrlString = "xcm/v2/xcm_fees.json"
        static let tokenUrlString = "xcm/v2/xcm_token_locations.json"
    }
}
