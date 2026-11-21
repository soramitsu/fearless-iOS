import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCABSWRecorder: UIViewController {
    private(set) var dismissCalls = 0
    private(set) var presentedControllers: [UIViewController] = []

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissCalls += 1
        completion?()
    }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCABSWNavigation: UINavigationController {
    var presenterStub: UIViewController?
    private(set) var popCalls = 0

    override var presentingViewController: UIViewController? { presenterStub }

    override func popViewController(animated _: Bool) -> UIViewController? {
        popCalls += 1
        return nil
    }
}

final class CovCABSWView: UIViewController, StakingAmountViewProtocol, ControllerAccountConfirmationViewProtocol {
    var presenterStub: UIViewController?
    var navigationStub: UINavigationController?
    private(set) var presentedControllers: [UIViewController] = []

    override var presentingViewController: UIViewController? { presenterStub }
    override var navigationController: UINavigationController? { navigationStub }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }

    func didReceive(viewModel _: StakingAmountMainViewModel) {}
    func didReceiveRewardDestination(viewModel _: LocalizableResource<RewardDestinationViewModelProtocol>) {}
    func didReceiveAsset(viewModel _: LocalizableResource<AssetBalanceViewModelProtocol>) {}
    func didReceiveFee(viewModel _: LocalizableResource<BalanceViewModelProtocol>?) {}
    func didReceiveInput(viewModel _: LocalizableResource<IAmountInputViewModel>) {}
    func reload(with _: LocalizableResource<ControllerAccountConfirmationVM>) {}
    func applyLocalization() {}
    func didStartLoading() {}
    func didStopLoading() {}
}

final class CovCABSWPickerDelegate: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_: Int, context _: AnyObject?) {}
}

final class CovCABStakingWireframesTests: XCTestCase {
    func testStakingAmountCloseDismissesPresenter() {
        let recorder = CovCABSWRecorder()
        let view = CovCABSWView()
        view.presenterStub = recorder

        StakingAmountWireframe().close(view: view)
        StakingAmountWireframe().close(view: nil)

        XCTAssertEqual(recorder.dismissCalls, 1)
    }

    func testStakingAmountPresentsPayoutAccountPicker() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let account = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest()))
        let view = CovCABSWView()
        let delegate = CovCABSWPickerDelegate()

        StakingAmountWireframe().presentAccountSelection(
            [account],
            selectedAccountItem: account,
            delegate: delegate,
            from: view,
            context: nil
        )

        XCTAssertEqual(view.presentedControllers.count, 1)
        XCTAssertEqual(view.presentedControllers.first?.modalPresentationStyle, .custom)
    }

    func testControllerAccountCloseDismissesPresenter() {
        let recorder = CovCABSWRecorder()
        let view = CovCABSWView()
        view.presenterStub = recorder

        ControllerAccountWireframe().close(view: view)

        XCTAssertEqual(recorder.dismissCalls, 1)
    }

    func testConfirmationCloseAndCompleteDismissAndNotify() {
        let recorder = CovCABSWRecorder()
        let navigation = CovCABSWNavigation()
        navigation.presenterStub = recorder
        let view = CovCABSWView()
        view.presenterStub = recorder
        view.navigationStub = navigation
        view.localizationManager = LocalizationManager(localization: "en")

        let wireframe = ControllerAccountConfirmationWireframe()
        wireframe.close(view: view)
        XCTAssertEqual(recorder.dismissCalls, 1)

        wireframe.complete(from: view)
        XCTAssertEqual(recorder.dismissCalls, 2)
        XCTAssertEqual(recorder.presentedControllers.count, 1)

        wireframe.complete(from: nil)
        XCTAssertEqual(recorder.dismissCalls, 2)
    }

    func testStakingBalanceCancelPopsNavigation() {
        let navigation = CovCABSWNavigation()
        let view = CovCABSWView()
        view.navigationStub = navigation

        StakingBalanceWireframe().cancel(from: view)
        StakingBalanceWireframe().cancel(from: nil)

        XCTAssertEqual(navigation.popCalls, 1)
    }
}
