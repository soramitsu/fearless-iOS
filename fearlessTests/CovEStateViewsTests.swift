@testable import fearless
import ImageIO
import UIKit
import XCTest

@MainActor
final class CovEStateViewsTests: XCTestCase {
    func testEmptyViewExposesItsContentAndRestylesForIconModeAndAlignment() throws {
        let view = EmptyView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 0, y: 80, width: 390, height: 400))
        defer { CovEHost.close(window) }

        let image = UIImage(systemName: "tray")
        view.image = image
        view.title = "Nothing here"
        view.text = "Your history is empty"
        XCTAssertEqual(view.image, image)
        XCTAssertEqual(view.title, "Nothing here")
        XCTAssertEqual(view.text, "Your history is empty")
        XCTAssertEqual(EmptyViewIconMode.bigFilledShadow.iconSize, 80)
        XCTAssertEqual(EmptyViewIconMode.smallFilled.iconSize, 56)

        let background = try XCTUnwrap(CovEFind.mirror(view, "imageBackgroundView", as: UIView.self))
        let container = try XCTUnwrap(CovEFind.mirror(view, "aligmentContainer", as: UIStackView.self))
        view.iconMode = .smallFilled
        XCTAssertEqual(background.backgroundColor, R.color.colorWhite4())
        view.contentAlignment = ContentAlignment(vertical: .top, horizontal: .center)
        XCTAssertEqual(container.alignment, .top)
        view.contentAlignment = ContentAlignment(vertical: .bottom, horizontal: .center)
        XCTAssertEqual(container.alignment, .bottom)
        view.verticalOffset = 24
        view.iconMode = .bigFilledShadow
        XCTAssertEqual(background.backgroundColor, R.color.colorBlack19())
        view.layoutIfNeeded()
        XCTAssertEqual(container.alignment, .bottom)
        XCTAssertNotNil(CovEFind.label("Nothing here", in: view))
    }

    func testChainCollectionKeepsRoomForTheOverflowCountAndClearsOldIcons() throws {
        let view = ChainCollectionView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 100, height: 16))
        defer { CovEHost.close(window) }
        let container = try XCTUnwrap(CovEFind.mirror(view, "containerView", as: UIView.self))
        let icons = (0 ..< 5).map { RemoteImageViewModel(url: URL(string: "https://icons.invalid/\($0).svg")!) }

        view.bind(viewModel: ChainCollectionViewModel(maxImagesCount: 3, chainImages: icons))
        XCTAssertEqual(container.subviews.compactMap { $0 as? UIImageView }.count, 3)
        XCTAssertEqual(CovEFind.texts(in: container), ["+2"])
        let xs = container.subviews.compactMap { $0 as? UIImageView }.map(\.frame.minX)
        XCTAssertEqual(xs, [64, 46, 28], "icons fill leftwards from the overflow label")

        view.bind(viewModel: ChainCollectionViewModel(maxImagesCount: 3, chainImages: Array(icons.prefix(2)) + [nil]))
        XCTAssertEqual(container.subviews.count, 3, "a fitting list replaces the old icons and drops the label")
        XCTAssertTrue(CovEFind.texts(in: container).isEmpty)
        XCTAssertEqual(container.subviews.map(\.frame.minX), [82, 64, 46])
    }

    func testGifDecodingSumsFrameDelaysAndBundledGifsAnimate() throws {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, 3, nil))
        let frame = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }.cgImage)
        for delay in [0.1, 0.2, 0.3] {
            let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
            CGImageDestinationAddImage(destination, frame, properties)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let gif = try XCTUnwrap(UIImage.makeGIFFromData(data: data as Data, repeatCount: 4))
        XCTAssertEqual(gif.images.count, 3)
        XCTAssertEqual(gif.durationInSec, 0.6, accuracy: 0.02)
        XCTAssertEqual(gif.repeatCount, 4)
        XCTAssertEqual(UIImage.makeGIFFromData(data: Data())?.images.count ?? 0, 0, "empty data has no frames")
        XCTAssertNil(UIImage.makeGIFFromCollection(name: "covE-missing-animation"))
        let plain = try XCTUnwrap(CGImageSourceCreateWithData(try XCTUnwrap(UIImage(cgImage: frame).pngData()) as CFData, nil))
        XCTAssertEqual(UIImage.delayForImageAtIndex(0, source: plain), 0, "a frame without GIF properties has no delay")

        let imageView = UIImageView()
        let window = CovEHost.window(for: imageView, frame: CGRect(x: 0, y: 100, width: 100, height: 100))
        defer { CovEHost.close(window) }
        imageView.setGIFImage(name: "animatedBg", repeatCount: 2)
        XCTAssertTrue(CovEHost.spin(until: { imageView.animationImages?.isEmpty == false }, timeout: 30))
        XCTAssertEqual(imageView.animationRepeatCount, 2)
        XCTAssertGreaterThan(imageView.animationDuration, 0)
        XCTAssertTrue(imageView.isAnimating)
        imageView.stopAnimating()
    }

    func testTriangularedViewGradientBorderAndFocusStates() throws {
        let view = TriangularedView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 300, height: 56))
        defer { CovEHost.close(window) }
        view.gradientBorderColors = [.red, .blue]
        view.strokeWidth = 2

        view.setGradientBorder(highlighted: true, animated: true)
        let borders = view.layer.sublayers?.filter { $0.name == "GradientBorderLayer" } ?? []
        XCTAssertEqual(borders.count, 1)
        let border = try XCTUnwrap(borders.first as? CAGradientLayer)
        XCTAssertEqual(border.colors?.count, 2)
        XCTAssertEqual(border.frame, view.bounds)
        XCTAssertNotNil(border.animation(forKey: "gradientAnimationKay"))
        XCTAssertEqual((border.mask as? CAShapeLayer)?.lineWidth, 2)

        view.setGradientBorder(highlighted: false, animated: true)
        XCTAssertEqual(view.layer.sublayers?.filter { $0.name == "GradientBorderLayer" }.count, 1, "the border layer is reused")
        XCTAssertEqual(border.colors?.count, 1)

        view.fwElevation = .flat
        view.fwFocused = true
        view.fwError = true
        XCTAssertNil(view.resolvedElevation)
        view.animateLayerStyle(to: true)
        view.fwElevation = .raised1
        XCTAssertEqual(view.resolvedElevation, .raised1)
        view.animateLayerStyle(to: false)
        XCTAssertTrue(view.fwFocused)
        XCTAssertTrue(view.fwError)
    }
}
