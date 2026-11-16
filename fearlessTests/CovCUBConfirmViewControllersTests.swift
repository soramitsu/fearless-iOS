import XCTest
import SoraFoundation
@testable import fearless

final class CovCUBConfirmPresenterSpy: StakingUnbondConfirmPresenterProtocol,
    StakingRedeemConfirmationPresenterProtocol,
    StakingRebondConfirmationPresenterProtocol {
    private(set) var calls: [String] = []

    func setup() { calls.append("setup") }
    func confirm() { calls.append("confirm") }
    func selectAccount() { calls.append("selectAccount") }
    func didTapBackButton() { calls.append("back") }
}

final class CovCUBConfirmViewControllersTests: XCTestCase {
    private let en = ["en"]
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func localization() throws -> LocalizationManagerProtocol {
        try XCTUnwrap(LocalizationManager(localization: "en"))
    }

    private func host(_ controller: UIViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        controller.view.layoutIfNeeded()
    }

    private func assetResource() -> LocalizableResource<AssetBalanceViewModelProtocol> {
        LocalizableResource { _ in
            AssetBalanceViewModel(
                symbol: "dot",
                balance: "9",
                fiatBalance: "$9",
                price: "$2.25",
                iconViewModel: nil,
                selectable: false
            )
        }
    }

    private func feeResource(_ amount: String) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { _ in BalanceViewModel(amount: amount, price: "$0.01") }
    }

    // MARK: - Unbond confirm

    func testUnbondConfirmControllerSetsUpAndForwardsActions() throws {
        let presenter = CovCUBConfirmPresenterSpy()
        let controller = StakingUnbondConfirmViewController(presenter: presenter, localizationManager: try localization())
        host(controller)

        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertEqual(controller.title, R.string.localizable.commonConfirmTitle(preferredLanguages: en))
        XCTAssertEqual(controller.rootView.locale.identifier, "en")

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "confirm", "back"])
    }

    func testUnbondConfirmControllerAppliesReceivedViewModels() throws {
        let presenter = CovCUBConfirmPresenterSpy()
        let controller = StakingUnbondConfirmViewController(presenter: presenter, localizationManager: try localization())
        host(controller)

        controller.didReceiveConfirmation(viewModel: StakingUnbondConfirmViewModel(
            senderAddress: "addr",
            senderIcon: nil,
            senderName: "Dave",
            stakeAmountViewModel: nil,
            amountString: LocalizableResource { _ in "5 DOT" },
            hints: LocalizableResource { _ in [TitleIconViewModel(title: "hint", icon: nil)] }
        ))
        controller.didReceiveAsset(viewModel: assetResource())
        controller.didReceiveFee(viewModel: feeResource("0.2 DOT"))
        controller.didReceiveBonding(duration: LocalizableResource { _ in
            TitleWithSubtitleViewModel(title: "Unstaking period", subtitle: "28 days")
        })

        let root = controller.rootView
        XCTAssertEqual(root.accountView.valueTop.text, "Dave")
        XCTAssertEqual(root.accountView.valueBottom.text, "addr")
        XCTAssertEqual(root.amountView.valueTop.text, "5 DOT")
        XCTAssertEqual(root.amountView.valueBottom.text, "$2.25")
        XCTAssertEqual(root.feeView.valueTop.text, "0.2 DOT")
        XCTAssertEqual(root.hintViews.count, 1)
        XCTAssertEqual(root.networkFeeFooterView.durationView?.titleLabel.text, "Unstaking period")
        XCTAssertEqual(root.networkFeeFooterView.durationView?.valueLabel.text, "28 days")

        controller.didReceiveFee(viewModel: nil)
        XCTAssertEqual(root.feeView.valueTop.text, "0.2 DOT")

        controller.applyLocalization()
        XCTAssertEqual(root.amountView.valueTop.text, "5 DOT")
        XCTAssertEqual(root.amountView.valueBottom.text, "$2.25")
    }

    func testUnbondConfirmControllerIgnoresSealWithoutLoader() throws {
        let controller = StakingUnbondConfirmViewController(
            presenter: CovCUBConfirmPresenterSpy(),
            localizationManager: try localization()
        )
        host(controller)
        let before = controller.view.subviews.count

        controller.didReachTransferStage(.ready)
        controller.didReachTransferStage(.signed)
        controller.didBreakTransfer()

        XCTAssertEqual(controller.view.subviews.count, before)
    }

    func testUnbondConfirmControllerLocalizationBeforeLoadDoesNothing() throws {
        let presenter = CovCUBConfirmPresenterSpy()
        let controller = StakingUnbondConfirmViewController(presenter: presenter, localizationManager: try localization())

        controller.applyLocalization()

        XCTAssertFalse(controller.isViewLoaded)
        XCTAssertTrue(presenter.calls.isEmpty)
    }

    // MARK: - Redeem confirmation

    func testRedeemConfirmationControllerSetsUpAndForwardsActions() throws {
        let presenter = CovCUBConfirmPresenterSpy()
        let controller = StakingRedeemConfirmationViewController(
            presenter: presenter,
            localizationManager: try localization()
        )
        host(controller)

        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertEqual(controller.rootView.locale.identifier, "en")

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "confirm", "back"])
    }

    func testRedeemConfirmationControllerAppliesReceivedViewModels() throws {
        let controller = StakingRedeemConfirmationViewController(
            presenter: CovCUBConfirmPresenterSpy(),
            localizationManager: try localization()
        )
        host(controller)

        controller.didReceiveConfirmation(viewModel: StakingRedeemConfirmationViewModel(
            senderAddress: "redeemer",
            senderIcon: nil,
            senderName: "Erin",
            stakeAmountViewModel: nil,
            amountString: LocalizableResource { _ in "6 DOT" },
            title: LocalizableResource { _ in "Redeem title" }
        ))
        controller.didReceiveAsset(viewModel: assetResource())
        controller.didReceiveFee(viewModel: feeResource("0.3 DOT"))
        controller.didReceiveHints(viewModel: LocalizableResource { _ in
            [TitleIconViewModel(title: "one", icon: nil), TitleIconViewModel(title: "two", icon: nil)]
        })

        let root = controller.rootView
        XCTAssertEqual(root.navigationBar.titleLabel.text, "Redeem title")
        XCTAssertEqual(root.accountView.valueTop.text, "Erin")
        XCTAssertEqual(root.accountView.valueBottom.text, "redeemer")
        XCTAssertEqual(root.amountView.valueTop.text, "6 DOT")
        XCTAssertEqual(root.amountView.valueBottom.text, "$2.25")
        XCTAssertEqual(root.feeView.valueTop.text, "0.3 DOT")
        XCTAssertEqual(root.hintViews.count, 2)

        controller.applyLocalization()
        XCTAssertEqual(root.navigationBar.titleLabel.text, "Redeem title")

        let before = controller.view.subviews.count
        controller.didReachTransferStage(.ready)
        controller.didBreakTransfer()
        XCTAssertEqual(controller.view.subviews.count, before)
    }

    // MARK: - Rebond confirmation

    func testRebondConfirmationControllerSetsUpAndForwardsActions() throws {
        let presenter = CovCUBConfirmPresenterSpy()
        let controller = StakingRebondConfirmationViewController(
            presenter: presenter,
            localizationManager: try localization()
        )
        host(controller)

        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertEqual(controller.title, R.string.localizable.commonConfirmTitle(preferredLanguages: en))

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.accountView.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "confirm", "selectAccount"])
    }

    func testRebondConfirmationControllerAppliesReceivedViewModels() throws {
        let controller = StakingRebondConfirmationViewController(
            presenter: CovCUBConfirmPresenterSpy(),
            localizationManager: try localization()
        )
        host(controller)

        controller.didReceiveConfirmation(viewModel: StakingRebondConfirmationViewModel(
            senderAddress: "rebonder",
            senderIcon: nil,
            senderName: nil,
            amount: LocalizableResource { _ in "7" }
        ))
        controller.didReceiveAsset(viewModel: assetResource())
        controller.didReceiveFee(viewModel: feeResource("0.4 DOT"))

        let root = controller.rootView
        XCTAssertEqual(root.accountView.subtitle, "rebonder")
        XCTAssertEqual(root.amountView.inputFieldText, "7")
        XCTAssertEqual(root.amountView.symbol, "DOT")
        XCTAssertEqual(root.networkFeeFooterView.networkFeeView?.tokenLabel.text, "0.4 DOT")

        controller.didReceiveFee(viewModel: nil)
        controller.applyLocalization()
        XCTAssertEqual(root.accountView.subtitle, "rebonder")

        let before = controller.view.subviews.count
        controller.didReachTransferStage(.sent)
        controller.didBreakTransfer()
        XCTAssertEqual(controller.view.subviews.count, before)
    }
}
