import Foundation
import SoraFoundation
import UIKit
import XCTest

@testable import fearless

final class CovDPoolListOutputSpy: LiquidityPoolsListViewOutput {
    private(set) var events: [String] = []

    func didLoad(view _: LiquidityPoolsListViewInput) { events.append("load") }
    func didTapOn(viewModel _: LiquidityPoolListCellModel) { events.append("tap") }
    func didTapMoreButton() { events.append("more") }
    func didTapBackButton() { events.append("back") }
    func searchTextDidChanged(_ text: String?) { events.append("search:\(text ?? "nil")") }
    func didAppearView() { events.append("appear") }
    func handleRefreshControlEvent() { events.append("refresh") }
}

final class CovDPoolListControlsTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    func testSearchRefreshAndKeyboardHooksReachThePresenter() throws {
        let output = CovDPoolListOutputSpy()
        let controller = LiquidityPoolsListViewController(output: output, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(controller)
        XCTAssertEqual(output.events.first, "load")

        controller.rootView.searchTextField.onTextDidChanged?("val")
        controller.perform(NSSelectorFromString("handleRefreshControlEvent"))
        XCTAssertEqual(output.events.filter { $0 != "load" && $0 != "appear" }, ["search:val", "refresh"])

        XCTAssertEqual(controller.offsetFromKeyboardWithInset(24), 0)
        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 500, width: 390, height: 300))
        XCTAssertNotNil(controller.target)
        XCTAssertEqual(controller.tableView(controller.rootView.tableView, numberOfRowsInSection: 0), 0)
    }
}
