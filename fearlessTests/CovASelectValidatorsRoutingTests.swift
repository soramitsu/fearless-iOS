import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovARoutingHostViewController: UIViewController, ControllerBackedProtocol,
    YourValidatorListViewProtocol, SelectValidatorsStartViewProtocol, RecommendedValidatorListViewProtocol,
    SelectedValidatorListViewProtocol, SelectValidatorsConfirmViewProtocol {
    func reload(state _: YourValidatorListViewState) {}
    func didStartLoading() {}
    func didStopLoading() {}
    func didReceive(viewModel _: SelectValidatorsStartViewModel?) {}
    func didReceive(textsViewModel _: SelectValidatorsStartTextsViewModel) {}
    func didReceive(viewModel _: RecommendedValidatorListViewModelProtocol) {}
    func didReload(_: SelectedValidatorListViewModel) {}
    func didChangeViewModel(_: SelectedValidatorListViewModel, byRemovingItemAt _: Int) {}
    func didReceive(confirmationViewModel _: LocalizableResource<SelectValidatorsConfirmViewModel>) {}
    func didReceive(hintsViewModel _: LocalizableResource<[TitleIconViewModel]>) {}
    func didReceive(assetViewModel _: LocalizableResource<AssetBalanceViewModelProtocol>) {}
    func didReceive(feeViewModel _: LocalizableResource<BalanceViewModelProtocol>?) {}
    func applyLocalization() {}
}

/// Routing through the real wireframes and the view factories that need no chain connection.
final class CovASelectValidatorsRoutingTests: XCTestCase {
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

    private func makeHost() -> (CovARoutingHostViewController, UINavigationController, UIWindow) {
        let host = CovARoutingHostViewController()
        let navigation = UINavigationController(rootViewController: host)
        let window = CovAViewInspector.host(navigation)
        return (host, navigation, window)
    }

    private func validators() -> [SelectedValidatorInfo] {
        [
            CovAFixtures.validator(1, identity: CovAFixtures.identity(name: "Route One"), stakeInfo: CovAFixtures.stakeInfo(maxNominatorsRewarded: 64)),
            CovAFixtures.validator(2)
        ]
    }

    private func customFlow() -> CustomValidatorListFlow {
        .relaychainInitiated(
            validatorList: validators(),
            recommendedValidatorList: validators(),
            selectedValidatorList: SharedList(items: [validators()[0]]),
            maxTargets: 4,
            bonding: CovAConfirmFixtures.initiated(payout: false)
        )
    }

    func testCustomValidatorListFactoryBuildsEveryFlow() throws {
        let list = validators()
        let selected = SharedList(items: [list[0]])
        let flows: [CustomValidatorListFlow] = [
            customFlow(),
            .relaychainExisting(
                validatorList: list, recommendedValidatorList: list, selectedValidatorList: selected,
                maxTargets: 4, bonding: CovAConfirmFixtures.existing(payout: true)
            ),
            .poolExisting(
                validatorList: list, recommendedValidatorList: list, selectedValidatorList: selected,
                poolId: 1, maxTargets: 4, bonding: CovAConfirmFixtures.existing(payout: false)
            ),
            .poolInitiated(
                validatorList: list, recommendedValidatorList: list, selectedValidatorList: selected,
                poolId: 1, maxTargets: 4, bonding: CovAConfirmFixtures.initiated(payout: true)
            )
        ]
        for flow in flows {
            let view = try XCTUnwrap(CustomValidatorListViewFactory.createView(chainAsset: chainAsset, wallet: wallet, flow: flow))
            let controller = try XCTUnwrap(view.controller as? CustomValidatorListViewController)
            let window = CovAViewInspector.host(UINavigationController(rootViewController: controller))
            XCTAssertEqual(controller.numberOfSections(in: controller.rootView.tableView), 1)
            window.isHidden = true
        }
    }

    /// Runs one route on a fresh navigation stack and returns the pushed screen, if any.
    private func route(waiting timeout: TimeInterval = 3, _ action: (CovARoutingHostViewController) -> Void) -> UIViewController? {
        let (host, navigation, window) = makeHost()
        action(host)
        CovAViewInspector.spin(until: { navigation.topViewController !== host }, timeout: timeout)
        let top = navigation.topViewController
        window.isHidden = true
        return top === host ? nil : top
    }

    func testCustomValidatorListWireframePushesFilterSearchAndSelectedList() {
        let wireframe = CustomValidatorListWireframe()
        XCTAssertTrue(route { host in
            wireframe.presentFilters(from: host, flow: .relaychain(filter: .recommendedFilter()), delegate: nil, asset: chainAsset.asset)
        } is ValidatorListFilterViewController)
        XCTAssertTrue(route { host in
            wireframe.proceed(
                from: host,
                flow: .relaychainInitiated(validatorList: validators(), maxTargets: 4, state: CovAConfirmFixtures.initiated(payout: false)),
                delegate: CovASelectedListDelegateSpy(),
                chainAsset: chainAsset,
                wallet: wallet
            )
        } is SelectedValidatorListViewController)
        XCTAssertNil(route(waiting: 0.3) { host in
            wireframe.confirm(
                from: host,
                flow: .relaychainInitiated(targets: validators(), maxTargets: 4, bonding: CovAConfirmFixtures.initiated(payout: false)),
                chainAsset: chainAsset,
                wallet: wallet
            )
        }, "a chain without a connection cannot confirm")
    }

    func testStartAndSelectedListWireframes() {
        let startWireframe = SelectValidatorsStartWireframe()
        XCTAssertTrue(route { host in
            startWireframe.proceedToCustomList(from: host, flow: customFlow(), chainAsset: chainAsset, wallet: wallet)
        } is CustomValidatorListViewController)
        XCTAssertTrue(route { host in
            startWireframe.proceedToRecommendedList(
                from: host,
                flow: .relaychainInitiated(validators: validators(), maxTargets: 4, bonding: CovAConfirmFixtures.initiated(payout: false)),
                wallet: wallet,
                chainAsset: chainAsset
            )
        } is RecommendedValidatorListViewController)
        let confirmFlow = SelectValidatorsConfirmFlow.relaychainInitiated(
            targets: validators(), maxTargets: 4, bonding: CovAConfirmFixtures.initiated(payout: false)
        )
        XCTAssertNil(route(waiting: 0.3) { host in
            SelectedValidatorListWireframe().proceed(from: host, flow: confirmFlow, wallet: wallet, chainAsset: chainAsset)
        })
        XCTAssertNil(route(waiting: 0.3) { host in
            RecommendedValidatorListWireframe().proceed(from: host, flow: confirmFlow, wallet: wallet, chainAsset: chainAsset)
        })
        XCTAssertNil(route(waiting: 0.3) { host in
            YourValidatorListWireframe().proceedToSelectValidatorsStart(
                from: host,
                chainAsset: chainAsset,
                wallet: wallet,
                flow: .relaychainExisting(state: CovAConfirmFixtures.existing(payout: false))
            )
        }, "starting needs a runtime for the chain")
    }

    func testDismissAndCloseReturnToThePreviousScreen() {
        for close in [{ (view: ControllerBackedProtocol) in SelectedValidatorListWireframe().dismiss(view) },
                      { (view: ControllerBackedProtocol) in ValidatorSearchWireframe().close(view) }] {
            let (host, navigation, window) = makeHost()
            let pushed = CovARoutingHostViewController()
            navigation.pushViewController(pushed, animated: false)
            CovAViewInspector.spin(until: { navigation.topViewController === pushed }, timeout: 2)
            close(pushed)
            CovAViewInspector.spin(until: { navigation.topViewController === host }, timeout: 2)
            XCTAssertTrue(navigation.topViewController === host)
            window.isHidden = true
        }
    }

    func testFactoriesThatNeedAConnectionRefuseUnknownChains() {
        XCTAssertNil(SelectValidatorsConfirmViewFactory.createView(
            chainAsset: chainAsset,
            flow: .relaychainInitiated(targets: validators(), maxTargets: 4, bonding: CovAConfirmFixtures.initiated(payout: false)),
            wallet: wallet
        ))
        XCTAssertNil(SelectValidatorsStartViewFactory.createView(
            wallet: wallet,
            chainAsset: chainAsset,
            flow: .relaychainInitiated(state: CovAConfirmFixtures.initiated(payout: false))
        ))
        XCTAssertNil(YourValidatorListViewFactory.createView(chainAsset: chainAsset, wallet: wallet, flow: .relaychain))
    }
}
