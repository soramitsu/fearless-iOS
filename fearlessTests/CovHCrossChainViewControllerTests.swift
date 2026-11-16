import XCTest
import UIKit
import SoraFoundation
import SoraUI
@testable import fearless

final class CovHCrossChainViewControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController() -> (CrossChainViewController, CovHCrossChainViewOutputSpy) {
        let output = CovHCrossChainViewOutputSpy()
        let controller = CrossChainViewController(output: output, localizationManager: LocalizationManager.shared)
        let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        host.rootViewController = controller
        host.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        window = host
        return (controller, output)
    }

    func testControlsForwardEveryTapToTheOutput() {
        let (controller, output) = makeController()
        XCTAssertEqual(output.loads, 1)
        let root = controller.rootView
        root.amountView.selectHandler?()
        root.destSelectNetworkView.sendActions(for: .touchUpInside)
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.actionButton.sendActions(for: .touchUpInside)
        root.scanButton.sendActions(for: .touchUpInside)
        root.historyButton.sendActions(for: .touchUpInside)
        root.myWalletsButton.sendActions(for: .touchUpInside)
        root.searchView.onPasteTapped?()
        XCTAssertEqual(output.calls, ["asset", "network", "back", "continue", "scan", "history", "wallets", "paste"])
        XCTAssertTrue(root.amountView.textField.inputAccessoryView is UIToolbar)
    }

    func testBindingsReachTheLayout() {
        let (controller, _) = makeController()
        let root = controller.rootView
        controller.didReceive(originFeeViewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.1 LLD", price: "$0.01") })
        XCTAssertFalse(root.originNetworkFeeView.isHidden)
        XCTAssertEqual(root.originNetworkFeeView.valueTop.text, "0.1 LLD")
        controller.didReceive(destinationFeeViewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.2 XOR", price: nil) })
        XCTAssertFalse(root.destinationNetworkFeeView.isHidden)
        XCTAssertEqual(root.destinationNetworkFeeView.valueTop.text, "0.2 XOR")
        controller.didReceive(originFeeViewModel: nil)
        XCTAssertTrue(root.originNetworkFeeView.isHidden)

        controller.didReceive(recipientViewModel: RecipientViewModel(address: "recipient", icon: nil, isValid: true, canEditing: true))
        XCTAssertEqual(root.searchView.textField.text, "recipient")
        XCTAssertTrue(root.searchView.isValid)

        controller.didReceive(assetBalanceViewModel: AssetBalanceViewModel(
            symbol: "LLD", balance: "10", fiatBalance: nil, price: nil, iconViewModel: nil, selectable: true
        ))
        controller.didReceive(assetBalanceViewModel: nil)
        controller.setButtonLoadingState(isLoading: true)
        controller.setButtonLoadingState(isLoading: false)
        XCTAssertFalse(root.actionButton.isEnabled, "No amount has been entered")
    }

    func testAmountInputRecalculatesAfterTheDebounce() throws {
        let (controller, output) = makeController()
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 8
        let input = AmountInputViewModel(symbol: "LLD", amount: nil, formatter: formatter, inputLocale: Locale(identifier: "en"), precision: 8)
        controller.didReceive(amountInputViewModel: input)
        let field = controller.rootView.amountView.textField
        XCTAssertTrue(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "5") == false)
        let expected = try XCTUnwrap(input.decimalAmount)
        CovHSendWait.until(timeout: 3) { !output.amounts.isEmpty }
        XCTAssertEqual(output.amounts, [expected])
        XCTAssertEqual(controller.rootView.amountView.inputFieldText, input.displayAmount)
    }

    func testSearchFieldEditingRulesAndAccessoryActions() {
        let (controller, output) = makeController()
        let search = controller.rootView.searchView.textField
        let amount = controller.rootView.amountView.textField

        XCTAssertFalse(controller.textField(search, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "a"))
        XCTAssertTrue(controller.textField(search, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: ""))
        XCTAssertFalse(controller.textField(amount, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "1"))
        XCTAssertTrue(controller.textField(UITextField(), shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        XCTAssertTrue(controller.textFieldShouldClear(search))
        XCTAssertTrue(controller.textFieldShouldClear(amount))
        search.text = "typed"
        XCTAssertFalse(controller.textFieldShouldReturn(search))
        amount.text = "1"
        XCTAssertFalse(controller.textFieldShouldReturn(amount))
        XCTAssertEqual(output.searches, ["", "", "typed"])

        controller.textFieldDidBeginEditing(search)
        controller.textFieldDidBeginEditing(amount)
        controller.textFieldDidEndEditing(amount)

        let accessory = AmountInputAccessoryView()
        controller.didSelect(on: accessory, percentage: 0.5)
        controller.didSelectDone(on: accessory)
        XCTAssertEqual(output.percentages, [0.5])
        XCTAssertFalse(search.isFirstResponder)
    }

    func testKeyboardHandlerFollowsAppearance() {
        let (controller, _) = makeController()
        controller.viewWillAppear(false)
        XCTAssertNotNil(controller.keyboardHandler)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(10), UIConstants.bigOffset)
        controller.updateWhileKeyboardFrameChanging(.zero)
        XCTAssertNotNil(controller.target)
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.locale, controller.selectedLocale)
    }
}

final class CovHCrossChainViewOutputSpy: CrossChainViewOutput {
    var loads = 0
    var calls: [String] = []
    var amounts: [Decimal] = []
    var percentages: [Float] = []
    var searches: [String] = []

    func didLoad(view _: CrossChainViewInput) { loads += 1 }
    func didTapSelectAsset() { calls.append("asset") }
    func didTapSelectDestNetwoek() { calls.append("network") }
    func updateAmount(_ newValue: Decimal) { amounts.append(newValue) }
    func selectAmountPercentage(_ percentage: Float) { percentages.append(percentage) }
    func didTapBackButton() { calls.append("back") }
    func didTapContinueButton() { calls.append("continue") }
    func didTapScanButton() { calls.append("scan") }
    func didTapHistoryButton() { calls.append("history") }
    func didTapMyWalletsButton() { calls.append("wallets") }
    func didTapPasteButton() { calls.append("paste") }
    func searchTextDidChanged(_ text: String) { searches.append(text) }
}
