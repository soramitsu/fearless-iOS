import UIKit
import XCTest
@testable import FearlessUI

final class SkrullBuilderTests: XCTestCase {
    func testSingleDecoration_whenStyled_thenProducesDecorationWithExpectedAttributes() throws {
        let decoration = SingleDecoration(
            position: CGPoint(x: 0.25, y: 0.5),
            size: CGSize(width: 10, height: 20)
        )
        .round(CGSize(width: 2, height: 3), mode: [.topLeft, .bottomRight])
        .fill(.red)
        .stroke(.blue, width: 2)
        .shadow(.black, offset: CGSize(width: 1, height: 2), radius: 4)

        XCTAssertTrue(decoration.shouldFill)
        XCTAssertTrue(decoration.shouldStroke)

        let model = try XCTUnwrap(decoration.decorations.first)
        XCTAssertEqual(decoration.decorations.count, 1)
        XCTAssertEqual(model.position, CGPoint(x: 0.25, y: 0.5))
        XCTAssertEqual(model.size, CGSize(width: 10, height: 20))
        XCTAssertEqual(model.cornerRadii, CGSize(width: 2, height: 3))
        XCTAssertEqual(model.cornerRoundingMode, [.topLeft, .bottomRight])
        XCTAssertEqual(model.fillColor, .red)
        XCTAssertEqual(model.strokeColor, .blue)
        XCTAssertEqual(model.strokeWidth, 2)
        XCTAssertEqual(model.shadowColor, .black)
        XCTAssertEqual(model.shadowOffset, CGSize(width: 1, height: 2))
        XCTAssertEqual(model.shadowRadius, 4)
        XCTAssertTrue(model.shouldFill)
        XCTAssertTrue(model.shouldStroke)
    }

    func testSingleSkeleton_whenStyled_thenProducesSkeletonWithExpectedAttributes() throws {
        let skeleton = SingleSkeleton(
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 44, height: 12)
        )
        .round(CGSize(width: 4, height: 4), mode: .allCorners)
        .fillStart(.lightGray)
        .fillEnd(.darkGray)

        let model = try XCTUnwrap(skeleton.skeletons.first)
        XCTAssertEqual(skeleton.skeletons.count, 1)
        XCTAssertEqual(model.position, CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(model.size, CGSize(width: 44, height: 12))
        XCTAssertEqual(model.cornerRadii, CGSize(width: 4, height: 4))
        XCTAssertEqual(model.cornerRoundingMode, .allCorners)
        XCTAssertEqual(model.startColor, .lightGray)
        XCTAssertEqual(model.endColor, .darkGray)
    }

    func testMultilineSkeleton_whenLastLineFractionProvided_thenBuildsStackedLines() {
        let skeletons = MultilineSkeleton(
            startLinePosition: CGPoint(x: 50, y: 10),
            lineSize: CGSize(width: 80, height: 12),
            count: 3,
            spacing: 4
        )
        .round()
        .fillStart(.white)
        .fillEnd(.gray)
        .lastLine(fraction: 0.5)
        .skeletons

        XCTAssertEqual(skeletons.count, 3)
        XCTAssertEqual(skeletons[0].position, CGPoint(x: 50, y: 10))
        XCTAssertEqual(skeletons[0].size, CGSize(width: 80, height: 12))
        XCTAssertEqual(skeletons[1].position, CGPoint(x: 50, y: 26))
        XCTAssertEqual(skeletons[1].size, CGSize(width: 80, height: 12))
        XCTAssertEqual(skeletons[2].position, CGPoint(x: 30, y: 42))
        XCTAssertEqual(skeletons[2].size, CGSize(width: 40, height: 12))
        XCTAssertEqual(skeletons[2].cornerRadii, CGSize(width: 0.5, height: 0.5))
        XCTAssertEqual(skeletons[2].startColor, .white)
        XCTAssertEqual(skeletons[2].endColor, .gray)
    }
}
