import UIKit
import XCTest
@testable import FearlessUI

@MainActor
final class ListViewLayoutStrategyTests: XCTestCase {
    func testHorizontalEqualWidthLayoutSplitsRectEvenly() {
        let strategy = HorizontalEqualWidthLayoutStrategy()
        let views = [UIView(), UIView(), UIView()]

        strategy.layout(
            views: views,
            in: CGRect(x: 10, y: 20, width: 90, height: 30)
        )

        XCTAssertEqual(views[0].frame, CGRect(x: 10, y: 20, width: 30, height: 30))
        XCTAssertEqual(views[1].frame, CGRect(x: 40, y: 20, width: 30, height: 30))
        XCTAssertEqual(views[2].frame, CGRect(x: 70, y: 20, width: 30, height: 30))
    }

    func testHorizontalFlexibleLayoutScalesMeasuredWidthsIntoRect() {
        let strategy = HorizontalFlexibleLayoutStrategy(margin: 5)
        let views = [
            SizeReportingView(width: 20),
            SizeReportingView(width: 30)
        ]

        strategy.layout(
            views: views,
            in: CGRect(x: 3, y: 7, width: 100, height: 44)
        )

        XCTAssertEqual(views[0].frame.origin.x, 3, accuracy: 0.001)
        XCTAssertEqual(views[0].frame.origin.y, 7, accuracy: 0.001)
        XCTAssertEqual(views[0].frame.width, 42.857, accuracy: 0.001)
        XCTAssertEqual(views[0].frame.height, 44, accuracy: 0.001)

        XCTAssertEqual(views[1].frame.origin.x, 45.857, accuracy: 0.001)
        XCTAssertEqual(views[1].frame.origin.y, 7, accuracy: 0.001)
        XCTAssertEqual(views[1].frame.width, 57.143, accuracy: 0.001)
        XCTAssertEqual(views[1].frame.height, 44, accuracy: 0.001)
    }
}

private final class SizeReportingView: UIView {
    private let fittingWidth: CGFloat

    init(width: CGFloat) {
        fittingWidth = width
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: fittingWidth, height: size.height)
    }
}
