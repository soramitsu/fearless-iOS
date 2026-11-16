@testable import fearless
import SoraUI
import UIKit
import XCTest

final class CovGFeeViewTests: XCTestCase {
    func testSingleTitleLoadingAndEditingTransitions() throws {
        let view = FeeView(frame: CGRect(x: 0, y: 0, width: 350, height: 50))
        let window = try host(view)
        defer { window.isHidden = true }
        view.contentInsets = UIEdgeInsets(top: 4, left: 12, bottom: 6, right: 14)
        view.horizontalSpacing = 9
        view.editIndicatorIcon = UIImage(systemName: "pencil")
        view.borderType = .all
        view.bind(viewModel: FeeViewModel(title: "Fee", details: "1 UNIT", isLoading: true, allowsEditing: true))
        view.layoutIfNeeded()
        XCTAssertEqual(view.titleLabel.text, "Fee 1 UNIT")
        XCTAssertNil(view.detailsLabel)
        XCTAssertTrue(view.activityIndicator.isAnimating)
        let icon = try XCTUnwrap(view.editingIconImageView)
        XCTAssertEqual(icon.image, view.editIndicatorIcon)
        XCTAssertEqual(icon.frame.maxX, 350 - 14, accuracy: 0.01)
        XCTAssertEqual(view.titleLabel.frame.minX, 12)
        XCTAssertEqual(view.titleLabel.frame.maxX + 9, icon.frame.minX, accuracy: 0.01)
        XCTAssertEqual(view.borderedView.frame, view.bounds)
        XCTAssertEqual(view.borderedView.borderType, view.borderType)
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 10)
        view.bind(viewModel: FeeViewModel(title: "Fee", details: "", isLoading: false, allowsEditing: false))
        view.layoutIfNeeded()
        XCTAssertEqual(view.titleLabel.text, "Fee")
        XCTAssertFalse(view.activityIndicator.isAnimating)
        XCTAssertNil(view.editingIconImageView)
        XCTAssertEqual(view.titleLabel.frame.maxX, 336, accuracy: 0.01)
    }

    func testSeparatedDetailsLayoutAndStylesAreUpdatedInPlace() throws {
        let view = FeeView(frame: CGRect(x: 0, y: 0, width: 350, height: 50))
        let window = try host(view)
        defer { window.isHidden = true }
        view.displayType = .separatedDetails
        view.detailsColor = .red
        view.detailsFont = .systemFont(ofSize: 15)
        view.editIndicatorIcon = UIImage(systemName: "pencil")
        view.bind(viewModel: FeeViewModel(title: "Network fee", details: "2 UNIT", isLoading: false, allowsEditing: true))
        view.layoutIfNeeded()
        let details = try XCTUnwrap(view.detailsLabel)
        let icon = try XCTUnwrap(view.editingIconImageView)
        XCTAssertEqual(view.titleLabel.text, "Network fee")
        XCTAssertEqual(details.text, "2 UNIT")
        XCTAssertEqual(details.textColor, .red)
        XCTAssertEqual(details.font, .systemFont(ofSize: 15))
        XCTAssertFalse(details.isHidden)
        XCTAssertLessThanOrEqual(view.titleLabel.frame.maxX, details.frame.minX)
        XCTAssertEqual(details.frame.maxX + view.horizontalSpacing, icon.frame.minX, accuracy: 0.01)
        view.detailsColor = .blue
        view.detailsFont = .systemFont(ofSize: 19)
        view.editIndicatorIcon = UIImage(systemName: "pencil.circle")
        view.bind(viewModel: FeeViewModel(title: "Fee", details: "3 UNIT", isLoading: true, allowsEditing: true))
        view.layoutIfNeeded()
        XCTAssertTrue(view.detailsLabel === details)
        XCTAssertTrue(view.editingIconImageView === icon)
        XCTAssertEqual(details.textColor, .blue)
        XCTAssertEqual(details.font, .systemFont(ofSize: 19))
        XCTAssertTrue(details.isHidden)
        XCTAssertEqual(view.activityIndicator.frame.maxX + view.horizontalSpacing, icon.frame.minX, accuracy: 0.01)
        view.bind(viewModel: FeeViewModel(title: "Fee", details: "4 UNIT", isLoading: true, allowsEditing: false))
        view.layoutIfNeeded()
        XCTAssertNil(view.editingIconImageView)
        XCTAssertEqual(view.activityIndicator.frame.maxX, view.bounds.maxX, accuracy: 0.01)
        view.displayType = .singleTitle
        XCTAssertNil(view.detailsLabel)
        XCTAssertEqual(view.titleLabel.text, "Fee 4 UNIT")
    }

    private func host(_ fee: FeeView) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.loadViewIfNeeded()
        controller.view.addSubview(fee)
        window.isHidden = false
        controller.view.layoutIfNeeded()
        return window
    }
}
