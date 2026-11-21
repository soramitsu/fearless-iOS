import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovANetworkInfoDelegateSpy: NetworkInfoViewDelegate {
    private(set) var expansions: [Bool] = []
    private(set) var animations = 0
    func animateAlongsideWithInfo(view _: NetworkInfoView) {
        animations += 1
    }

    func didChangeExpansion(isExpanded: Bool, view _: NetworkInfoView) {
        expansions.append(isExpanded)
    }
}

final class CovANetworkInfoViewTests: XCTestCase {
    func testManualLayoutBindsRowsLoadingAndExpansion() {
        let view = NetworkInfoView(frame: CGRect(x: 0, y: 0, width: 358, height: 320))
        let delegate = CovANetworkInfoDelegateSpy()
        view.delegate = delegate
        let controller = UIViewController()
        let window = CovAViewInspector.host(controller)
        controller.view.addSubview(view)
        view.frame = CGRect(x: 16, y: 80, width: 358, height: 320)
        view.layoutIfNeeded()

        view.bind(viewModels: [])
        view.didAppearSkeleton()
        view.didUpdateSkeletonLayout()
        view.didDisappearSkeleton()
        view.bind(viewModels: [
            LocalizableResource { _ in NetworkInfoContentViewModel(title: "Total staked", value: "1000 COV", details: "$2000") },
            LocalizableResource { _ in NetworkInfoContentViewModel(title: "Nominators", value: "10", details: nil) }
        ])
        view.layoutIfNeeded()
        XCTAssertTrue(CovAViewInspector.contains("1000 COV", in: view))
        XCTAssertTrue(CovAViewInspector.contains("Nominators", in: view))

        view.setExpanded(false, animated: false)
        view.setExpanded(true, animated: true)
        view.setExpanded(true, animated: false)
        view.actionToggleExpansion()
        XCTAssertFalse(delegate.expansions.isEmpty)

        view.bind(chainName: "Cov Relay")
        view.bind(viewModel: nil)
        view.startLoading()
        view.stopLoadingIfNeeded()
        window.isHidden = true
    }
}
