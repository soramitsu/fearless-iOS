import Foundation
import SoraFoundation
import UIKit
import XCTest

@testable import fearless

final class CovDAmountInput: IAmountInputViewModel {
    let symbol = "UNIT"
    var displayAmount = "1"
    var decimalAmount: Decimal? = 1
    var isValid = true
    let observable = WalletViewModelObserverContainer<AmountInputViewModelObserver>()
    var replacements: [String] = []
    func didReceiveReplacement(_ string: String, for _: NSRange) -> Bool {
        replacements.append(string)
        return false
    }
}

final class CovDInputOutputSpy: LiquidityPoolSupplyViewOutput, LiquidityPoolRemoveLiquidityViewOutput, PolkaswapAdjustmentViewOutput {
    var loads = 0
    var fromAmounts: [Decimal] = []
    var toAmounts: [Decimal] = []
    var fromPercentages: [Float] = []
    var toPercentages: [Float] = []
    var toSelections = 0
    func didLoad(view _: LiquidityPoolSupplyViewInput) { loads += 1 }
    func didLoad(view _: LiquidityPoolRemoveLiquidityViewInput) { loads += 1 }
    func didLoad(view _: PolkaswapAdjustmentViewInput) { loads += 1 }
    func handleViewAppeared() {}
    func viewDidAppear() {}
    func didTapBackButton() {}
    func didTapApyInfo() {}
    func didTapPreviewButton() {}
    func didTapFeeInfo() {}
    func didTapMarketButton() {}
    func didTapSelectFromAsset() {}
    func didTapSelectToAsset() { toSelections += 1 }
    func didTapSwitchInputsButton() {}
    func didTapMinReceiveInfo() {}
    func didTapNetworkFeeInfo() {}
    func selectFromAmountPercentage(_ percentage: Float) { fromPercentages.append(percentage) }
    func selectToAmountPercentage(_ percentage: Float) { toPercentages.append(percentage) }
    func updateFromAmount(_ newValue: Decimal) { fromAmounts.append(newValue) }
    func updateToAmount(_ newValue: Decimal) { toAmounts.append(newValue) }
}

final class CovDInputControlsTests: XCTestCase {
    func testSupplyInputsForwardAmountsPercentagesAndEndEditing() throws {
        let output = CovDInputOutputSpy()
        let controller = LiquidityPoolSupplyViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovDFixtures.host(controller)
        defer { CovDFixtures.tearDown(window) }
        let from = CovDAmountInput()
        let to = CovDAmountInput()
        to.displayAmount = "2"
        to.decimalAmount = 2
        controller.didReceiveSwapFrom(amountInputViewModel: from)
        controller.didReceiveSwapTo(amountInputViewModel: to)
        let fromField = controller.rootView.swapFromInputView.textField
        let toField = controller.rootView.swapToInputView.textField
        // The amount fields stay locked until the first quote is ready.
        XCTAssertFalse(fromField.isUserInteractionEnabled)
        controller.didReceiveSwapQuoteReady()
        XCTAssertTrue(fromField.isUserInteractionEnabled)
        XCTAssertTrue(toField.isUserInteractionEnabled)
        let accessory = AmountInputAccessoryView()
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(controller.rootView.swapFromInputView.inputFieldText, "1")
        XCTAssertEqual(controller.rootView.swapToInputView.inputFieldText, "2")
        XCTAssertTrue(fromField.becomeFirstResponder())
        controller.didSelect(on: accessory, percentage: 0.25)
        XCTAssertEqual(output.fromPercentages, [0.25])
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.fromAmounts.last == 1 })
        XCTAssertFalse(controller.textField(fromField, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "3"))
        XCTAssertEqual(from.replacements, ["3"])
        XCTAssertTrue(controller.textField(UITextField(), shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "4"))
        controller.didSelectDone(on: accessory)
        XCTAssertFalse(fromField.isFirstResponder)
        XCTAssertTrue(toField.becomeFirstResponder())
        controller.didSelect(on: accessory, percentage: 0.5)
        XCTAssertEqual(output.toPercentages, [0.5])
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.toAmounts.last == 2 })
        XCTAssertFalse(controller.textField(toField, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "5"))
        XCTAssertEqual(to.replacements, ["5"])
        to.decimalAmount = nil
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.toAmounts.last == 0 })
        controller.didSelectDone(on: accessory)
        XCTAssertFalse(toField.isFirstResponder)
        XCTAssertTrue(fromField.becomeFirstResponder())
        from.decimalAmount = nil
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.fromAmounts.last == 0 })
        controller.didSelectDone(on: accessory)
        controller.didReceiveSwapFrom(amountInputViewModel: nil)
        XCTAssertFalse(controller.textField(fromField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "6"))
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(0), UIConstants.bigOffset)
        XCTAssertNotNil(controller.target)
    }

    func testRemovalInputsForwardAmountsPercentagesAndEndEditing() throws {
        let output = CovDInputOutputSpy()
        let controller = LiquidityPoolRemoveLiquidityViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovDFixtures.host(controller)
        defer { CovDFixtures.tearDown(window) }
        let from = CovDAmountInput()
        let to = CovDAmountInput()
        to.displayAmount = "2"
        to.decimalAmount = 2
        controller.didReceiveSwapFrom(amountInputViewModel: from)
        controller.didReceiveSwapTo(amountInputViewModel: to)
        let fromField = controller.rootView.swapFromInputView.textField
        let toField = controller.rootView.swapToInputView.textField
        // The amount fields stay locked until the first quote is ready.
        XCTAssertFalse(fromField.isUserInteractionEnabled)
        controller.didReceiveSwapQuoteReady()
        XCTAssertTrue(fromField.isUserInteractionEnabled)
        XCTAssertTrue(toField.isUserInteractionEnabled)
        let accessory = AmountInputAccessoryView()
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(controller.rootView.swapFromInputView.inputFieldText, "1")
        XCTAssertEqual(controller.rootView.swapToInputView.inputFieldText, "2")
        XCTAssertTrue(fromField.becomeFirstResponder())
        controller.didSelect(on: accessory, percentage: 0.25)
        XCTAssertEqual(output.fromPercentages, [0.25])
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.fromAmounts.last == 1 })
        XCTAssertFalse(controller.textField(fromField, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "3"))
        XCTAssertEqual(from.replacements, ["3"])
        XCTAssertTrue(controller.textField(UITextField(), shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "4"))
        controller.didSelectDone(on: accessory)
        XCTAssertFalse(fromField.isFirstResponder)
        XCTAssertTrue(toField.becomeFirstResponder())
        controller.didSelect(on: accessory, percentage: 0.5)
        XCTAssertEqual(output.toPercentages, [0.5])
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.toAmounts.last == 2 })
        XCTAssertFalse(controller.textField(toField, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "5"))
        XCTAssertEqual(to.replacements, ["5"])
        to.decimalAmount = nil
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.toAmounts.last == 0 })
        controller.didSelectDone(on: accessory)
        XCTAssertFalse(toField.isFirstResponder)
        XCTAssertTrue(fromField.becomeFirstResponder())
        from.decimalAmount = nil
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.fromAmounts.last == 0 })
        controller.didSelectDone(on: accessory)
        controller.didReceiveSwapFrom(amountInputViewModel: nil)
        XCTAssertFalse(controller.textField(fromField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "6"))
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(0), UIConstants.bigOffset)
        XCTAssertNotNil(controller.target)
    }

    func testSwapInputsForwardAmountsPercentagesAndEndEditing() throws {
        let output = CovDInputOutputSpy()
        let controller = PolkaswapAdjustmentViewController(output: output, bannersViewController: UIViewController(), localizationManager: LocalizationManager.shared)
        let window = try CovDFixtures.host(controller)
        defer { CovDFixtures.tearDown(window) }
        let from = CovDAmountInput()
        let to = CovDAmountInput()
        to.displayAmount = "2"
        to.decimalAmount = 2
        controller.didReceiveSwapFrom(amountInputViewModel: from)
        controller.didReceiveSwapTo(amountInputViewModel: to)
        let fromField = controller.rootView.swapFromInputView.textField
        let toField = controller.rootView.swapToInputView.textField
        let accessory = AmountInputAccessoryView()
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(controller.rootView.swapFromInputView.inputFieldText, "1")
        XCTAssertEqual(controller.rootView.swapToInputView.inputFieldText, "2")
        XCTAssertTrue(fromField.becomeFirstResponder())
        controller.didSelect(on: accessory, percentage: 0.25)
        XCTAssertEqual(output.fromPercentages, [0.25])
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.fromAmounts.last == 1 })
        XCTAssertFalse(controller.textField(fromField, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "3"))
        XCTAssertEqual(from.replacements, ["3"])
        XCTAssertTrue(controller.textField(UITextField(), shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "4"))
        controller.didSelectDone(on: accessory)
        XCTAssertFalse(fromField.isFirstResponder)
        XCTAssertTrue(toField.becomeFirstResponder())
        controller.didSelect(on: accessory, percentage: 0.5)
        XCTAssertEqual(output.toPercentages, [0.5])
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.toAmounts.last == 2 })
        XCTAssertFalse(controller.textField(toField, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "5"))
        XCTAssertEqual(to.replacements, ["5"])
        to.decimalAmount = nil
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.toAmounts.last == 0 })
        controller.didSelectDone(on: accessory)
        XCTAssertFalse(toField.isFirstResponder)
        XCTAssertTrue(fromField.becomeFirstResponder())
        from.decimalAmount = nil
        controller.amountInputDidChange()
        XCTAssertTrue(CovDFixtures.spin { output.fromAmounts.last == 0 })
        controller.didSelectDone(on: accessory)
        controller.didReceiveSwapFrom(amountInputViewModel: nil)
        XCTAssertFalse(controller.textField(fromField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "6"))
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(0), UIConstants.bigOffset)
        XCTAssertNotNil(controller.target)
    }

}
