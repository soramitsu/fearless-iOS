import Foundation
import SoraFoundation
import UIKit
import XCTest

@testable import fearless

final class CovDSlippageOutputSpy: PolkaswapTransaktionSettingsViewOutput {
    private(set) var values: [Float] = []
    private(set) var loads = 0

    func didLoad(view _: PolkaswapTransaktionSettingsViewInput) { loads += 1 }
    func didTapSelectMarket() {}
    func didChangeSlider(value: Float) { values.append(value) }
    func didTapBackButton() {}
    func didTapResetButton() {}
    func didTapSaveButton() {}
}

final class CovDSettingsInputTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func type(_ text: String, into field: UITextField, of controller: PolkaswapTransaktionSettingsViewController) -> Bool {
        let length = (field.text ?? "").count
        return controller.textField(field, shouldChangeCharactersIn: NSRange(location: length, length: 0), replacementString: text)
    }

    func testSlippageFieldAcceptsUpToTwoDecimalsAndAppliesAfterAPause() throws {
        let output = CovDSlippageOutputSpy()
        let controller = PolkaswapTransaktionSettingsViewController(output: output, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(controller)
        XCTAssertEqual(output.loads, 1)
        let field = controller.rootView.slippageToleranceView.textField
        XCTAssertTrue(field.inputAccessoryView is AmountInputAccessoryView)
        field.text = "0.5%"

        controller.textFieldDidBeginEditing(field)
        XCTAssertEqual(field.text, "")
        XCTAssertTrue(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: ""))
        XCTAssertFalse(type("1", into: field, of: controller))
        XCTAssertFalse(type(",", into: field, of: controller))
        XCTAssertEqual(field.text, "1.")
        XCTAssertFalse(type("25", into: field, of: controller))
        XCTAssertEqual(field.text, "1.25")
        XCTAssertFalse(type("9", into: field, of: controller))
        XCTAssertEqual(field.text, "1.25")
        XCTAssertTrue(CovDFixtures.spin(timeout: 3) { output.values == [1.25] })

        // A value still ending in a separator is not applied.
        field.text = "3"
        XCTAssertFalse(type(".", into: field, of: controller))
        XCTAssertEqual(field.text, "3.")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.2))
        XCTAssertEqual(output.values, [1.25])

        field.text = ""
        controller.textFieldDidEndEditing(field)
        XCTAssertEqual(output.values.last, controller.rootView.slippageToleranceSlider.value)

        controller.didSelect(on: AmountInputAccessoryView(), percentage: 3)
        XCTAssertEqual(output.values.last, 3)
        XCTAssertTrue(field.becomeFirstResponder())
        controller.didSelectDone(on: AmountInputAccessoryView())
        XCTAssertFalse(field.isFirstResponder)

        let other = UITextField()
        other.text = "keep"
        controller.textFieldDidBeginEditing(other)
        XCTAssertEqual(other.text, "keep")
    }
}
