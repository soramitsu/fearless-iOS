import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCPJJoinConfigOutputDouble: StakingPoolJoinConfigViewOutput {
    private(set) var loadedView: StakingPoolJoinConfigViewInput?
    private(set) var percentages: [Float] = []
    private(set) var amounts: [Decimal] = []
    private(set) var backTaps = 0
    private(set) var continueTaps = 0

    func didLoad(view: StakingPoolJoinConfigViewInput) { loadedView = view }
    func selectAmountPercentage(_ percentage: Float) { percentages.append(percentage) }
    func updateAmount(_ newValue: Decimal) { amounts.append(newValue) }
    func didTapBackButton() { backTaps += 1 }
    func didTapContinueButton() { continueTaps += 1 }
}

final class CovCPJJoinConfigViewTests: XCTestCase {
    private let languages = CovCPJFixtures.languages

    private func makeLayout() -> StakingPoolJoinConfigViewLayout {
        let view = StakingPoolJoinConfigViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = CovCPJFixtures.locale
        view.layoutIfNeeded()
        return view
    }

    private func makeController() throws -> (StakingPoolJoinConfigViewController, CovCPJJoinConfigOutputDouble) {
        let output = CovCPJJoinConfigOutputDouble()
        let controller = StakingPoolJoinConfigViewController(
            output: output,
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        controller.loadViewIfNeeded()
        return (controller, output)
    }

    private func balanceFactory() -> BalanceViewModelFactory {
        CovCPJFixtures.balanceFactory(chainAsset: CovCPJFixtures.chainAsset(), wallet: CovCPJFixtures.wallet())
    }

    func testLayoutLocalizesTitles() {
        let view = makeLayout()

        XCTAssertEqual(view.accountView.title, R.string.localizable.poolStakingJoinAccountTitle(preferredLanguages: languages))
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.poolStakingJoinTitle(preferredLanguages: languages))
        // ede0cdd81 sets `feeView.locale` before the Join title, so the footer no longer resets it to Confirm.
        XCTAssertEqual(
            view.feeView.actionButton.imageWithTitleView?.title,
            R.string.localizable.poolStakingJoinButtonTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(view.feeView.locale.identifier, "en")
    }

    func testBindAccountViewModelUsesFallbackIcon() {
        let view = makeLayout()

        view.bind(accountViewModel: AccountViewModel(title: "Join", name: "My wallet", icon: nil))

        XCTAssertEqual(view.accountView.subtitle, "My wallet")
        XCTAssertNotNil(view.accountView.iconImage)
    }

    func testBindAssetViewModelShowsSymbol() {
        let view = makeLayout()

        view.bind(assetViewModel: balanceFactory().createAssetBalanceViewModel(1, balance: 8, priceData: nil).value(for: CovCPJFixtures.locale))

        let texts = CovCPJFixtures.labelTexts(in: view.amountView)
        XCTAssertTrue(texts.contains("DOT"))
        XCTAssertTrue(texts.contains { $0.contains("8") })
    }

    func testControllerLoadsWithDisabledActionAndForwardsTaps() throws {
        let (controller, output) = try makeController()

        XCTAssertTrue(output.loadedView === controller)
        XCTAssertFalse(controller.rootView.feeView.actionButton.isEnabled)
        XCTAssertTrue(controller.rootView.amountView.textField.inputAccessoryView is AmountInputAccessoryView)

        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.feeView.actionButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.backTaps, 1)
        XCTAssertEqual(output.continueTaps, 1)
    }

    func testControllerBindsViewModels() throws {
        let (controller, _) = try makeController()
        let factory = balanceFactory()
        let window = CovCPJFixtures.host(controller)

        controller.didReceiveAccountViewModel(AccountViewModel(title: "Join", name: "Wallet A", icon: nil))
        controller.didReceiveAssetBalanceViewModel(
            factory.createAssetBalanceViewModel(2, balance: 5, priceData: nil).value(for: CovCPJFixtures.locale)
        )
        controller.didReceiveFeeViewModel(BalanceViewModel(amount: "0.05 DOT", price: nil))
        controller.didReceive(locale: CovCPJFixtures.locale)

        XCTAssertEqual(controller.rootView.accountView.subtitle, "Wallet A")
        XCTAssertEqual(controller.rootView.feeView.networkFeeView?.tokenLabel.text, "0.05 DOT")
        XCTAssertFalse(controller.rootView.feeView.actionButton.isEnabled)
        XCTAssertEqual(controller.rootView.locale.identifier, "en")
        window.isHidden = true
    }

    func testControllerEnablesActionForValidAmountAndForwardsTyping() throws {
        let (controller, output) = try makeController()
        let factory = balanceFactory()
        let field = controller.rootView.amountView.textField

        XCTAssertFalse(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "1"))

        controller.didReceiveAmountInputViewModel(factory.createBalanceInputViewModel(4).value(for: CovCPJFixtures.locale))
        XCTAssertEqual(field.text, "4")
        XCTAssertTrue(controller.rootView.feeView.actionButton.isEnabled)

        controller.didReceiveAmountInputViewModel(factory.createBalanceInputViewModel(nil).value(for: CovCPJFixtures.locale))
        XCTAssertFalse(controller.rootView.feeView.actionButton.isEnabled)

        _ = controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "3")
        XCTAssertEqual(output.amounts.last, 3)
        XCTAssertEqual(field.text, "3")
    }

    func testControllerAccessoryAndLocalization() throws {
        let (controller, output) = try makeController()
        let accessory = try XCTUnwrap(controller.rootView.amountView.textField.inputAccessoryView as? AmountInputAccessoryView)

        accessory.actionSelect75()
        accessory.actionSelect100()
        accessory.actionSelectDone()
        controller.rootView.locale = Locale(identifier: "ja")
        controller.applyLocalization()

        XCTAssertEqual(output.percentages, [0.75, 1])
        XCTAssertEqual(controller.rootView.locale.identifier, controller.selectedLocale.identifier)
    }
}
