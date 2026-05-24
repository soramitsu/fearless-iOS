import XCTest
@testable import FearlessUI

final class BorderTypeTests: XCTestCase {
    func testAllContainsEveryBorder() {
        XCTAssertTrue(BorderType.all.contains(.top))
        XCTAssertTrue(BorderType.all.contains(.left))
        XCTAssertTrue(BorderType.all.contains(.bottom))
        XCTAssertTrue(BorderType.all.contains(.right))
        XCTAssertFalse(BorderType.none.contains(.top))
    }

    func testSetOperationsUpdateRawValue() {
        var borders: BorderType = [.top, .left]

        borders.formUnion(.bottom)
        XCTAssertTrue(borders.contains(.top))
        XCTAssertTrue(borders.contains(.left))
        XCTAssertTrue(borders.contains(.bottom))
        XCTAssertFalse(borders.contains(.right))

        borders.formIntersection([.left, .right])
        XCTAssertEqual(borders, .left)

        borders.formSymmetricDifference([.left, .right])
        XCTAssertEqual(borders, .right)
    }
}
