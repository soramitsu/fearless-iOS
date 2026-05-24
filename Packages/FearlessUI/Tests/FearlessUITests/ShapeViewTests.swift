import UIKit
import XCTest
@testable import FearlessUI

@MainActor
final class ShapeViewTests: XCTestCase {
    func testShapeView_whenLayerStyleChanges_thenAppliesShapeLayerProperties() throws {
        let view = ShapeView(frame: CGRect(x: 0, y: 0, width: 20, height: 10))
        let layer = try XCTUnwrap(view.layer as? CAShapeLayer)

        view.fillColor = .red
        view.strokeColor = .blue
        view.strokeWidth = 2
        view.layoutSubviews()

        XCTAssertEqual(layer.fillColor, UIColor.red.cgColor)
        XCTAssertEqual(layer.strokeColor, UIColor.blue.cgColor)
        XCTAssertEqual(layer.lineWidth, 2)
        XCTAssertNotNil(layer.path)
    }

    func testShapeView_whenHighlightedWithoutAnimation_thenAppliesHighlightedColors() throws {
        let view = ShapeView(frame: CGRect(x: 0, y: 0, width: 20, height: 10))
        let layer = try XCTUnwrap(view.layer as? CAShapeLayer)

        view.highlightedFillColor = .green
        view.highlightedStrokeColor = .yellow
        view.set(highlighted: true, animated: false)

        XCTAssertEqual(layer.fillColor, UIColor.green.cgColor)
        XCTAssertEqual(layer.strokeColor, UIColor.yellow.cgColor)
    }

    func testShadowShapeView_whenShadowPropertiesChange_thenAppliesShapeLayerShadow() throws {
        let view = ShadowShapeView(frame: CGRect(x: 0, y: 0, width: 20, height: 10))
        let layer = try XCTUnwrap(view.layer as? CAShapeLayer)

        view.shadowOpacity = 0.25
        view.shadowColor = .purple
        view.shadowRadius = 7
        view.shadowOffset = CGSize(width: 2, height: 3)
        view.layoutSubviews()

        XCTAssertEqual(layer.shadowOpacity, 0.25)
        XCTAssertEqual(layer.shadowColor, UIColor.purple.cgColor)
        XCTAssertEqual(layer.shadowRadius, 7)
        XCTAssertEqual(layer.shadowOffset, CGSize(width: 2, height: 3))
        XCTAssertNotNil(layer.shadowPath)
    }

    func testRoundedView_whenCornerConfigurationChanges_thenUpdatesRoundedShapePath() throws {
        let view = RoundedView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        let layer = try XCTUnwrap(view.layer as? CAShapeLayer)

        view.cornerRadius = 6
        view.roundingCorners = [.topLeft, .bottomRight]
        view.layoutSubviews()

        XCTAssertNotNil(layer.path)
        XCTAssertEqual(view.cornerRadius, 6)
        XCTAssertEqual(view.roundingCorners, [.topLeft, .bottomRight])
    }
}
