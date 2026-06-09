import UIKit
import XCTest
@testable import FearlessUI

@MainActor
final class ProgressViewTests: XCTestCase {
    func testSetProgressClampsLowerBound() {
        let view = ProgressView(frame: CGRect(x: 0, y: 0, width: 100, height: 12))

        view.setProgress(-0.5, animated: false)

        XCTAssertEqual(view.progress, 0)
    }

    func testSetProgressClampsUpperBound() {
        let view = ProgressView(frame: CGRect(x: 0, y: 0, width: 100, height: 12))

        view.setProgress(1.5, animated: false)

        XCTAssertEqual(view.progress, 1)
    }

    func testProgressColorUpdatesProgressLayer() throws {
        let view = ProgressView(frame: CGRect(x: 0, y: 0, width: 100, height: 12))
        let progressLayer = try XCTUnwrap(view.layer.sublayers?.first as? CAShapeLayer)

        view.progressColor = .red

        XCTAssertEqual(progressLayer.fillColor, UIColor.red.cgColor)
    }
}
