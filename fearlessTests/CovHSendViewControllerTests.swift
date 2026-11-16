import XCTest
import UIKit
import SoraFoundation
@testable import fearless

final class CovHSendViewControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController() -> (SendViewController, CovHSendViewOutputSpy) {
        let output = CovHSendViewOutputSpy()
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh View", assetUtility: true)
        let controller = SendViewController(initialData: .chainAsset(chainAsset), output: output, localizationManager: LocalizationManager.shared)
        let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        host.rootViewController = controller
        host.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        window = host
        return (controller, output)
    }

    func testSelectorsAndAccessoryReachTheOutput() {
        let (controller, output) = makeController()
        controller.rootView.amountView.selectHandler?()
        controller.perform(Selector(("selectNetworkClicked")))
        let accessory = AmountInputAccessoryView()
        controller.didSelect(on: accessory, percentage: 0.25)
        controller.didSelectDone(on: accessory)
        XCTAssertEqual(output.assetTaps, 1)
        XCTAssertEqual(output.networkTaps, 1)
        XCTAssertEqual(output.percentages, [0.25])
        XCTAssertFalse(controller.rootView.amountView.textField.isFirstResponder)
    }

    func testAccessoryVisibilityAndBlockedInteraction() {
        let (controller, _) = makeController()
        let root = controller.rootView
        controller.setInputAccessoryView(visible: true)
        XCTAssertNotNil(root.amountView.textField.inputAccessoryView)
        controller.setInputAccessoryView(visible: false)
        XCTAssertNil(root.amountView.textField.inputAccessoryView)

        controller.didBlockUserInteractive(isUserInteractiveAmount: false)
        XCTAssertFalse(root.searchView.isUserInteractionEnabled)
        XCTAssertFalse(root.selectNetworkView.isUserInteractionEnabled)
        XCTAssertFalse(root.amountView.textField.isUserInteractionEnabled)
        XCTAssertTrue(root.optionsStackView.isHidden)
        XCTAssertNil(root.amountView.selectHandler)

        controller.didBlockUserInteractive(isUserInteractiveAmount: true)
        XCTAssertTrue(root.amountView.textField.isUserInteractionEnabled)
    }

    func testLoadingAndTipStatesKeepTheButtonConsistent() {
        let (controller, _) = makeController()
        controller.didStartLoading()
        controller.didStopLoading()
        controller.didStopTipCalculation()
        XCTAssertFalse(controller.rootView.actionButton.isEnabled, "Nothing has been entered")
    }

    func testSearchFieldEditingRules() {
        let (controller, output) = makeController()
        let search = controller.rootView.searchView.textField
        search.text = "abc"
        XCTAssertTrue(controller.textField(search, shouldChangeCharactersIn: NSRange(location: 2, length: 1), replacementString: ""))
        XCTAssertEqual(search.text, "")
        XCTAssertFalse(controller.textField(search, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "pasted"))
        XCTAssertFalse(controller.textField(search, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        XCTAssertFalse(controller.textField(UITextField(), shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        search.text = "typed"
        XCTAssertFalse(controller.textFieldShouldReturn(search))
        let other = UITextField()
        other.text = "ignored"
        XCTAssertFalse(controller.textFieldShouldReturn(other))
        XCTAssertEqual(output.searches, ["", "pasted", "typed"])
    }
}

final class CovHSendViewOutputSpy: SendViewOutput {
    var loads = 0
    var assetTaps = 0
    var networkTaps = 0
    var percentages: [Float] = []
    var searches: [String] = []
    var amounts: [Decimal] = []

    func didLoad(view _: SendViewInput) { loads += 1 }
    func didTapBackButton() {}
    func didTapContinueButton() {}
    func didTapScanButton() {}
    func didTapHistoryButton() {}
    func didTapPasteButton() {}
    func didTapSelectAsset() { assetTaps += 1 }
    func didTapSelectNetwork() { networkTaps += 1 }
    func searchTextDidChanged(_ text: String) { searches.append(text) }
    func selectAmountPercentage(_ percentage: Float, validate _: Bool) { percentages.append(percentage) }
    func didEditAmount(_ newValue: Decimal) -> () -> Void { { [weak self] in self?.amounts.append(newValue) } }
    func updateAmount(_ newValue: Decimal) { amounts.append(newValue) }
    func didSwitchSendAll(_: Bool) {}
}
