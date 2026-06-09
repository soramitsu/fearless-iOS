import UIKit
import XCTest
@testable import FearlessUI

@MainActor
final class ControlsAndLoadingTests: XCTestCase {
    func testHighlightableExtensions_whenCalled_thenUpdateHighlightedState() {
        let label = UILabel()
        let imageView = UIImageView()

        label.set(highlighted: true, animated: true)
        imageView.set(highlighted: true, animated: false)

        XCTAssertTrue(label.isHighlighted)
        XCTAssertTrue(imageView.isHighlighted)
    }

    func testGradientView_whenPropertiesChange_thenAppliesGradientLayerStyle() throws {
        let view = GradientView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let layer = try XCTUnwrap(view.layer as? CAGradientLayer)

        view.startColor = .red
        view.endColor = .blue
        view.startPoint = CGPoint(x: 0.1, y: 0.2)
        view.endPoint = CGPoint(x: 0.9, y: 0.8)
        view.transitionLocation = 0.75
        view.cornerRadius = 8
        view.layoutSubviews()

        XCTAssertEqual(layer.colors as? [CGColor], [UIColor.red.cgColor, UIColor.blue.cgColor])
        XCTAssertEqual(layer.startPoint, CGPoint(x: 0.1, y: 0.2))
        XCTAssertEqual(layer.endPoint, CGPoint(x: 0.9, y: 0.8))
        XCTAssertEqual(layer.locations, [NSNumber(value: Float(0.75))])
        XCTAssertNotNil(layer.mask)
    }

    func testGradientView_whenCornerRadiusIsZero_thenRemovesMask() throws {
        let view = GradientView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let layer = try XCTUnwrap(view.layer as? CAGradientLayer)

        view.cornerRadius = 8
        view.layoutSubviews()
        XCTAssertNotNil(layer.mask)

        view.cornerRadius = 0
        view.layoutSubviews()

        XCTAssertNil(layer.mask)
    }

    func testBorderedContainerView_whenBorderAndLineCapChange_thenUpdatesShapeLayer() throws {
        let view = BorderedContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let layer = try XCTUnwrap(view.layer as? CAShapeLayer)

        view.borderType = [.top, .bottom]
        view.lineCap = .round
        view.layoutSubviews()

        XCTAssertEqual(view.borderType, [.top, .bottom])
        XCTAssertEqual(layer.lineCap, .round)
        XCTAssertNotNil(layer.path)
    }

    func testLoadingView_whenConfigured_thenStoresContentAndAnimationSettings() throws {
        let view = LoadingView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let image = UIImage()

        view.contentSize = CGSize(width: 72, height: 80)
        view.contentCornerRadius = 12
        view.contentBackgroundColor = .black
        view.indicatorImage = image
        view.animationDuration = 2.5

        let animation = try XCTUnwrap(view.createAnimation() as? CAKeyframeAnimation)

        XCTAssertEqual(view.contentSize, CGSize(width: 72, height: 80))
        XCTAssertEqual(view.contentCornerRadius, 12)
        XCTAssertEqual(view.contentBackgroundColor, .black)
        XCTAssertTrue(view.indicatorImage === image)
        XCTAssertEqual(animation.keyPath, "transform.rotation.z")
        XCTAssertEqual(animation.duration, 2.5)
        XCTAssertEqual(animation.repeatDuration, .infinity)
    }

    func testLoadingView_whenStartAndStopAnimating_thenUpdatesAnimatingState() {
        let view = LoadingView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))

        view.startAnimating()
        XCTAssertTrue(view.isAnimating)

        view.startAnimating()
        XCTAssertTrue(view.isAnimating)

        view.stopAnimating()
        XCTAssertFalse(view.isAnimating)

        view.stopAnimating()
        XCTAssertFalse(view.isAnimating)
    }

    func testPageLoadingView_whenStartedAndStopped_thenControlsActivityIndicator() {
        let view = PageLoadingView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))

        view.verticalMargin = 12
        let expectedHeight = view.activityIndicatorView.intrinsicContentSize.height + 24

        XCTAssertEqual(view.intrinsicContentSize.height, expectedHeight)

        view.start()
        XCTAssertTrue(view.activityIndicatorView.isAnimating)

        view.stop()
        XCTAssertFalse(view.activityIndicatorView.isAnimating)
    }
}
