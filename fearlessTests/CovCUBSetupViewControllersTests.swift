import XCTest
import SSFUtils
import SoraFoundation
@testable import fearless

final class CovCUBSetupPresenterSpy: StakingUnbondSetupPresenterProtocol, StakingRebondSetupPresenterProtocol {
    private(set) var calls: [String] = []
    private(set) var percentages: [Float] = []
    private(set) var amounts: [Decimal] = []

    func setup() { calls.append("setup") }
    func selectAmountPercentage(_ percentage: Float) {
        calls.append("percentage")
        percentages.append(percentage)
    }

    func updateAmount(_ newValue: Decimal) {
        calls.append("amount")
        amounts.append(newValue)
    }

    func proceed() { calls.append("proceed") }
    func close() { calls.append("close") }
    func didTapBackButton() { calls.append("back") }
}

final class CovCUBSetupViewControllersTests: XCTestCase {
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

    private func inputResource(_ amount: Decimal?) -> LocalizableResource<IAmountInputViewModel> {
        CovCUBFixture.balanceFactory(wallet: CovCUBFixture.wallet()).createBalanceInputViewModel(amount)
    }

    private func assetResource() -> LocalizableResource<AssetBalanceViewModelProtocol> {
        LocalizableResource { _ in
            AssetBalanceViewModel(
                symbol: "dot",
                balance: "11",
                fiatBalance: nil,
                price: "$3",
                iconViewModel: nil,
                selectable: false
            )
        }
    }

    private func accessory(of field: UITextField) throws -> AmountInputAccessoryView {
        try XCTUnwrap(field.inputAccessoryView as? AmountInputAccessoryView)
    }

    // MARK: - Unbond setup

    func testUnbondSetupControllerLoadsAndForwardsButtons() throws {
        let presenter = CovCUBSetupPresenterSpy()
        let controller = StakingUnbondSetupViewController(presenter: presenter, localizationManager: try localization())
        host(controller)

        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertTrue(controller.rootView.amountInputView.textField.delegate === controller)
        XCTAssertNotNil(controller.rootView.amountInputView.textField.inputAccessoryView)
        XCTAssertFalse(controller.rootView.networkFeeFooterView.actionButton.isEnabled)

        controller.didReceiveInput(viewModel: inputResource(1))
        XCTAssertTrue(controller.rootView.networkFeeFooterView.actionButton.isEnabled)
        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "proceed", "back"])
    }

    func testUnbondSetupControllerAppliesReceivedViewModels() throws {
        let presenter = CovCUBSetupPresenterSpy()
        let controller = StakingUnbondSetupViewController(presenter: presenter, localizationManager: try localization())
        host(controller)
        let root = controller.rootView

        let icon = try PolkadotIconGenerator().generateFromAddress("5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq")
        controller.didReceiveAccount(viewModel: AccountViewModel(title: "Account", name: "Frank", icon: icon))
        XCTAssertFalse(root.accountView.isHidden)
        XCTAssertEqual(root.accountView.title, "Account")
        XCTAssertEqual(root.accountView.subtitle, "Frank")
        XCTAssertNotNil(root.accountView.iconImage)

        controller.didReceiveAsset(viewModel: assetResource())
        XCTAssertEqual(root.amountInputView.symbol, "DOT")
        XCTAssertEqual(root.amountInputView.balanceText, R.string.localizable.stakingBondedFormat("11", preferredLanguages: en))

        let footer: LocalizableResource<NetworkFeeFooterViewModelProtocol> = LocalizableResource { _ in
            NetworkFeeFooterViewModel(
                actionTitle: LocalizableResource { _ in "Continue now" },
                feeTitle: LocalizableResource { _ in "Fee" },
                balanceViewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.05 DOT", price: nil) }
            )
        }
        controller.didReceiveFee(viewModel: footer)
        XCTAssertEqual(root.networkFeeFooterView.actionButton.imageWithTitleView?.title, "Continue now")
        XCTAssertEqual(root.networkFeeFooterView.networkFeeView?.tokenLabel.text, "0.05 DOT")

        controller.didReceiveBonding(duration: LocalizableResource { _ in
            TitleWithSubtitleViewModel(title: "Period", subtitle: "7 days")
        })
        XCTAssertEqual(root.networkFeeFooterView.durationView?.valueLabel.text, "7 days")

        controller.didReceiveTitle(viewModel: LocalizableResource { _ in "Unstake" })
        XCTAssertEqual(root.navigationBar.titleLabel.text, "Unstake")

        controller.didReceiveHints(viewModel: LocalizableResource { _ in [TitleIconViewModel(title: "x", icon: nil)] })
        XCTAssertEqual(root.hintViews.count, 1)

        controller.applyLocalization()
        XCTAssertEqual(root.networkFeeFooterView.durationView?.titleLabel.text, "Period")
        XCTAssertEqual(root.amountInputView.symbol, "DOT")
    }

    func testUnbondSetupControllerInputDrivesPresenterAndButtonState() throws {
        let presenter = CovCUBSetupPresenterSpy()
        let controller = StakingUnbondSetupViewController(presenter: presenter, localizationManager: try localization())
        host(controller)
        let field = controller.rootView.amountInputView.textField

        controller.didReceiveInput(viewModel: inputResource(nil))
        XCTAssertFalse(controller.rootView.networkFeeFooterView.actionButton.isEnabled)
        XCTAssertFalse(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "3"))

        XCTAssertEqual(presenter.amounts, [3])
        XCTAssertEqual(field.text, "3")
        XCTAssertTrue(controller.rootView.networkFeeFooterView.actionButton.isEnabled)

        controller.didReceiveInput(viewModel: inputResource(2))
        XCTAssertEqual(field.text, "2")
        XCTAssertTrue(controller.rootView.networkFeeFooterView.actionButton.isEnabled)

        try accessory(of: field).actionSelect50()
        try accessory(of: field).actionSelectDone()
        XCTAssertEqual(presenter.percentages, [0.5])
        XCTAssertEqual(presenter.calls.filter { $0 == "percentage" }.count, 1)
    }

    func testUnbondSetupControllerWithoutInputModelRejectsReplacement() throws {
        let controller = StakingUnbondSetupViewController(
            presenter: CovCUBSetupPresenterSpy(),
            localizationManager: try localization()
        )
        controller.loadViewIfNeeded()

        let allowed = controller.textField(
            controller.rootView.amountInputView.textField,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "1"
        )
        XCTAssertFalse(allowed)
    }

    // MARK: - Rebond setup

    func testRebondSetupControllerLoadsAndForwardsActions() throws {
        let presenter = CovCUBSetupPresenterSpy()
        let controller = StakingRebondSetupViewController(presenter: presenter, localizationManager: try localization())
        host(controller)

        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertEqual(controller.title, R.string.localizable.stakingRebond(preferredLanguages: en))
        XCTAssertFalse(controller.rootView.actionButton.isEnabled)

        controller.didReceiveInput(viewModel: inputResource(1))
        XCTAssertTrue(controller.rootView.actionButton.isEnabled)
        controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "proceed"])

        let closeItem = try XCTUnwrap(controller.navigationItem.leftBarButtonItem)
        let target = try XCTUnwrap(closeItem.target as? NSObject)
        let action = try XCTUnwrap(closeItem.action)
        target.perform(action)
        XCTAssertEqual(presenter.calls, ["setup", "proceed", "close"])
    }

    func testRebondSetupControllerAppliesViewModelsAndInput() throws {
        let presenter = CovCUBSetupPresenterSpy()
        let controller = StakingRebondSetupViewController(presenter: presenter, localizationManager: try localization())
        host(controller)
        let root = controller.rootView

        controller.didReceiveAsset(viewModel: assetResource())
        XCTAssertEqual(root.amountInputView.symbol, "DOT")
        XCTAssertEqual(root.amountInputView.balanceText, R.string.localizable.commonBalanceFormat("11", preferredLanguages: en))

        controller.didReceiveFee(viewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.06 DOT", price: "$0.1") })
        XCTAssertEqual(root.networkFeeView.tokenLabel.text, "0.06 DOT")
        controller.didReceiveFee(viewModel: nil)
        XCTAssertEqual(root.networkFeeView.tokenLabel.text, "0.06 DOT")

        controller.didReceiveInput(viewModel: inputResource(nil))
        let field = root.amountInputView.textField
        XCTAssertFalse(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "4"))
        XCTAssertEqual(presenter.amounts, [4])
        XCTAssertTrue(root.actionButton.isEnabled)

        try accessory(of: field).actionSelect25()
        try accessory(of: field).actionSelectDone()
        XCTAssertEqual(presenter.percentages, [0.25])

        controller.applyLocalization()
        XCTAssertEqual(controller.title, R.string.localizable.stakingRebond(preferredLanguages: en))
        XCTAssertEqual(root.networkFeeView.tokenLabel.text, "0.06 DOT")
    }
}
