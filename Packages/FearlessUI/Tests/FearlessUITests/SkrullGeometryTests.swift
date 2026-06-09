import UIKit
import XCTest
@testable import FearlessUI

final class SkrullGeometryTests: XCTestCase {
    func testSkrullAnchorPoints_matchExpectedUnitCoordinates() {
        XCTAssertEqual(CGPoint.skrullTopLeft, CGPoint(x: 0, y: 0))
        XCTAssertEqual(CGPoint.skrullTopRight, CGPoint(x: 1, y: 0))
        XCTAssertEqual(CGPoint.skrullBottomLeft, CGPoint(x: 0, y: 1))
        XCTAssertEqual(CGPoint.skrullBottomRight, CGPoint(x: 1, y: 1))
        XCTAssertEqual(CGPoint.skrullCenter, CGPoint(x: 0.5, y: 0.5))
    }

    func testSkrullMap_whenSizeProvided_thenNormalizesCoordinates() {
        let size = CGSize(width: 200, height: 100)

        XCTAssertEqual(size.skrullMapX(50), 0.25)
        XCTAssertEqual(size.skrullMapY(25), 0.25)
        XCTAssertEqual(size.skrullMap(point: CGPoint(x: 100, y: 75)), CGPoint(x: 0.5, y: 0.75))
    }
}
