import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovHNftSendViewOutputSpy: NftSendViewOutput {
    private(set) var calls: [String] = []
    private(set) var texts: [String] = []

    func didLoad(view _: NftSendViewInput) { calls.append("load") }
    func didBackButtonTapped() { calls.append("back") }
    func didTapScanButton() { calls.append("scan") }
    func didTapHistoryButton() { calls.append("history") }
    func didTapPasteButton() { calls.append("paste") }
    func didTapContinueButton() { calls.append("continue") }
    func searchTextDidChanged(_ text: String) { texts.append(text) }
    func didTapMyWalletsButton() { calls.append("wallets") }
}

final class CovHNftSendViewControllerTests: XCTestCase {
    func testButtonsAndTextFieldForwardToOutput() {
        let output = CovHNftSendViewOutputSpy()
        let controller = NftSendViewController(output: output, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        let root = controller.rootView

        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.scanButton.sendActions(for: .touchUpInside)
        root.historyButton.sendActions(for: .touchUpInside)
        root.actionButton.sendActions(for: .touchUpInside)
        root.myWalletsButton.sendActions(for: .touchUpInside)
        root.searchView.onPasteTapped?()
        XCTAssertEqual(output.calls, ["load", "back", "scan", "history", "continue", "wallets", "paste"])

        let field = root.searchView.textField
        field.text = "abc"
        XCTAssertFalse(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 3, length: 0), replacementString: "d"))
        XCTAssertTrue(controller.textFieldShouldClear(field))
        XCTAssertFalse(controller.textFieldShouldReturn(field))
        let otherField = UITextField()
        XCTAssertFalse(controller.textField(otherField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        XCTAssertTrue(controller.textFieldShouldClear(otherField))
        otherField.text = nil
        XCTAssertFalse(controller.textFieldShouldReturn(otherField))
        controller.textFieldDidBeginEditing(field)
        controller.textFieldDidEndEditing(field)
        XCTAssertEqual(output.texts, ["abcd", "", "abc"])
    }

    func testViewModelsUpdateLayoutAndKeyboardHooks() {
        let output = CovHNftSendViewOutputSpy()
        let controller = NftSendViewController(output: output, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        let root = controller.rootView

        controller.didReceive(feeViewModel: BalanceViewModel(amount: "0.01 CVH", price: "$1"))
        XCTAssertEqual(root.feeView.tokenLabel.text, "0.01 CVH")

        controller.didReceive(scamInfo: ScamInfo(name: "Scammer", address: "a", type: .scam, subtype: "Phishing"))
        XCTAssertFalse(root.scamWarningView.isHidden)
        XCTAssertTrue(CovHNftViews.texts(in: root.scamWarningView).contains("Scammer"))
        controller.didReceive(scamInfo: nil)
        XCTAssertTrue(root.scamWarningView.isHidden)

        controller.didReceive(viewModel: RecipientViewModel(address: "recipient", icon: nil, isValid: true, canEditing: true))
        XCTAssertEqual(root.searchView.textField.text, "recipient")
        XCTAssertTrue(root.actionButton.isEnabled)
        controller.didReceive(viewModel: RecipientViewModel(address: "bad", icon: nil, isValid: false, canEditing: true))
        XCTAssertFalse(root.actionButton.isEnabled)

        XCTAssertTrue(controller.target === root.keyboardAdoptableConstraint)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(10), UIConstants.bigOffset)
        controller.updateWhileKeyboardFrameChanging(.zero)
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        controller.applyLocalization()
        XCTAssertEqual(root.locale, controller.selectedLocale)
    }

    func testLayoutLocalizesTitles() {
        let layout = NftSendViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        layout.locale = Locale(identifier: "de")
        let english = Locale(identifier: "en")
        layout.locale = english
        XCTAssertEqual(layout.navigationTitleLabel.text, R.string.localizable.chooseRecipientTitle(preferredLanguages: english.rLanguages))
        XCTAssertEqual(layout.actionButton.imageWithTitleView?.title, R.string.localizable.commonContinue(preferredLanguages: english.rLanguages))
        XCTAssertEqual(
            layout.historyButton.imageWithTitleView?.title,
            R.string.localizable.walletSearchContacts(preferredLanguages: english.rLanguages).uppercased()
        )
        XCTAssertEqual(layout.searchView.titleLabel.text, R.string.localizable.searchViewTitle(preferredLanguages: english.rLanguages))
        layout.bind(feeViewModel: nil)
        XCTAssertNil(layout.feeView.tokenLabel.text)
    }
}
