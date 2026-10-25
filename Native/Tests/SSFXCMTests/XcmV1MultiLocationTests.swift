import BigInt
import XCTest

@testable import SSFXCM

final class XcmV1MultiLocationTests: XCTestCase {
    func testXcmV1MultiLocationInit() {
        // arrange
        let parents: UInt8 = 0
        let interior: XcmV1MultilocationJunctions = .init(items: [.onlyChild])

        // act
        let location = XcmV1MultiLocation(parents: parents, interior: interior)

        // assert
        XCTAssertEqual(location.parents, parents)
        XCTAssertEqual(location.interior, interior)
    }
}
