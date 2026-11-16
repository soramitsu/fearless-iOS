import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

/// Validator info and search modules build without a chain connection; every wireframe that opens them pushes them.
final class CovAValidatorInfoRoutingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UIView.setAnimationsEnabled(false)
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        super.tearDown()
    }

    private let chainAsset = CovAFixtures.chainAsset()
    private let wallet = CovAFixtures.wallet()

    private func validator() -> SelectedValidatorInfo {
        CovAFixtures.validator(1, identity: CovAFixtures.identity(name: "Info Route"))
    }

    private func makeHost() -> (CovARoutingHostViewController, UINavigationController, UIWindow) {
        let host = CovARoutingHostViewController()
        let navigation = UINavigationController(rootViewController: host)
        let window = CovAViewInspector.host(navigation)
        return (host, navigation, window)
    }

    func testFactoriesBuildInfoAndSearchModules() throws {
        let relay = try XCTUnwrap(ValidatorInfoViewFactory.createView(
            chainAsset: chainAsset, wallet: wallet, flow: .relaychain(validatorInfo: validator(), address: nil)
        ))
        XCTAssertTrue(relay.controller is ValidatorInfoViewController)
        let pool = try XCTUnwrap(ValidatorInfoViewFactory.createView(
            chainAsset: chainAsset, wallet: wallet, flow: .pool(validatorInfo: validator(), address: nil)
        ))
        XCTAssertTrue(pool.controller is ValidatorInfoViewController)

        let search = try XCTUnwrap(ValidatorSearchViewFactory.createView(
            chainAsset: chainAsset,
            flow: .relaychain(validatorList: [validator()], selectedValidatorList: [], delegate: CovASearchDelegateSpy()),
            wallet: wallet
        ))
        XCTAssertTrue(search.controller is ValidatorSearchViewController)

        let window = CovAViewInspector.host(UINavigationController(rootViewController: relay.controller))
        relay.controller.view.layoutIfNeeded()
        XCTAssertTrue(CovAViewInspector.contains("Info Route", in: relay.controller.view))
        window.isHidden = true
    }

    private func pushed(_ action: (CovARoutingHostViewController) -> Void) -> UIViewController? {
        let (host, navigation, window) = makeHost()
        action(host)
        CovAViewInspector.spin(until: { navigation.topViewController !== host }, timeout: 3)
        let top = navigation.topViewController
        window.isHidden = true
        return top === host ? nil : top
    }

    func testWireframesPushValidatorInfo() {
        let flow = ValidatorInfoFlow.relaychain(validatorInfo: validator(), address: nil)
        let fromCustomList = pushed { CustomValidatorListWireframe().present(chainAsset: chainAsset, wallet: wallet, flow: flow, from: $0) }
        XCTAssertTrue(fromCustomList is ValidatorInfoViewController)
        let search = pushed { host in
            CustomValidatorListWireframe().presentSearch(
                from: host,
                flow: .relaychain(validatorList: [validator()], selectedValidatorList: [], delegate: CovASearchDelegateSpy()),
                chainAsset: chainAsset,
                wallet: wallet
            )
        }
        XCTAssertTrue(search is ValidatorSearchViewController)
        let fromSelected = pushed { SelectedValidatorListWireframe().present(flow: flow, chainAsset: chainAsset, wallet: wallet, from: $0) }
        XCTAssertTrue(fromSelected is ValidatorInfoViewController)
        let fromRecommended = pushed { RecommendedValidatorListWireframe().present(flow: flow, chainAsset: chainAsset, wallet: wallet, from: $0) }
        XCTAssertTrue(fromRecommended is ValidatorInfoViewController)
        let fromYours = pushed { YourValidatorListWireframe().present(flow: flow, chainAsset: chainAsset, wallet: wallet, from: $0) }
        XCTAssertTrue(fromYours is ValidatorInfoViewController)
        let fromSearch = pushed { ValidatorSearchWireframe().present(flow: flow, chainAsset: chainAsset, wallet: wallet, from: $0) }
        XCTAssertTrue(fromSearch is ValidatorInfoViewController)
    }

    func testStakingMainOpensYourValidatorInfoModally() {
        let host = CovAStakingMainViewStub()
        StakingMainWireframe().showYourValidatorInfo(
            chainAsset: chainAsset,
            selectedAccount: wallet,
            flow: .relaychain(validatorInfo: nil, address: CovAFixtures.address(1)),
            from: host
        )
        XCTAssertEqual(host.presentedControllers.count, 1)
    }
}
