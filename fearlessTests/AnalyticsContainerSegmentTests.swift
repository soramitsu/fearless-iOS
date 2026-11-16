import SoraFoundation
import UIKit
import XCTest
@testable import fearless

/// Choosing a tab of the staking analytics screen shows that tab's page. The handler always scrolled to the first
/// page, whatever tab was chosen.
final class AnalyticsContainerSegmentTests: XCTestCase {
    func testChoosingATabScrollsToItsPage() throws {
        let modules = (0 ..< 3).map { AnalyticsSegmentPageStub(title: "Page \($0)") }
        let controller = AnalyticsContainerViewController(
            embeddedModules: modules,
            localizationManager: LocalizationManager.shared
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        controller.view.layoutIfNeeded()
        let scrollView = controller.rootView.horizontalScrollView
        let pageWidth = scrollView.frame.width
        XCTAssertGreaterThan(pageWidth, 0)

        for index in [2, 1, 0] {
            controller.rootView.segmentedControl.selectedSegmentIndex = index
            controller.rootView.segmentedControl.sendActions(for: .valueChanged)

            let expectedOffset = pageWidth * CGFloat(index)
            let deadline = Date().addingTimeInterval(3)
            while abs(scrollView.contentOffset.x - expectedOffset) > 0.5, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            XCTAssertEqual(scrollView.contentOffset.x, expectedOffset, accuracy: 0.5, "tab \(index)")
        }
    }
}

private final class AnalyticsSegmentPageStub: UIViewController, AnalyticsEmbeddedViewProtocol {
    let localizedTitle: LocalizableResource<String>

    init(title: String) {
        localizedTitle = LocalizableResource { _ in title }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
