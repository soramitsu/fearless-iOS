import Foundation
import UIKit
import XCTest
@testable import fearless

final class CovGAccountManagementTests: XCTestCase {
    func testCreateAndBackupFlowsArePresentedInsideNavigationControllers() throws {
        let presenter = CovGAccountManagementPresenter()
        let view = CovGManagementHost()
        presenter.showCreateNewWallet(from: view)
        let create = try XCTUnwrap(view.captured as? FearlessNavigationController)
        XCTAssertNotNil(create.viewControllers.first)
        view.captured = nil
        presenter.showBackupSelectWallet(from: view)
        let backup = try XCTUnwrap(view.captured as? FearlessNavigationController)
        XCTAssertNotNil(backup.viewControllers.first)
    }
}

private final class CovGAccountManagementPresenter: AccountManagementPresentable {}

private final class CovGManagementHost: UIViewController, ControllerBackedProtocol {
    var controller: UIViewController {
        self
    }

    var captured: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        captured = viewControllerToPresent
        completion?()
    }
}
