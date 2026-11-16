import XCTest
import UIKit
import SoraFoundation
import SoraUI
@testable import fearless

final class CovJBackupCreateOutput: BackupCreatePasswordViewOutput {
    var loads = 0
    var backs = 0
    var continues = 0
    func didLoad(view: BackupCreatePasswordViewInput) { loads += 1 }
    func didTapBackButton() { backs += 1 }
    func didTapContinueButton() { continues += 1 }
}

final class CovJBackupPasswordOutput: BackupPasswordViewOutput {
    var loads = 0
    var backs = 0
    var continues = 0
    func didLoad(view: BackupPasswordViewInput) { loads += 1 }
    func didBackButtonTapped() { backs += 1 }
    func didContinueButtonTapped() { continues += 1 }
}

final class CovJBackupControllersTests: XCTestCase {
    func testCreatePasswordRequiresMatchingInputsAndAcknowledgement() throws {
        let output = CovJBackupCreateOutput()
        let controller = BackupCreatePasswordViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.applyLocalization()
        let password = InputHandler(predicate: NSPredicate.backupPassword)
        let confirmation = InputHandler(predicate: NSPredicate.notEmpty)
        controller.setPasswordInputViewModel(InputViewModel(inputHandler: password))
        controller.setPasswordConfirmationViewModel(InputViewModel(inputHandler: confirmation))
        let root = controller.rootView
        XCTAssertEqual(output.loads, 1)
        XCTAssertFalse(root.continueButton.isEnabled)
        password.changeValue(to: "short")
        root.passwordTextField.animatedInputField.sendActions(for: .editingChanged)
        XCTAssertEqual(root.passwordTextField.text, "short")
        XCTAssertFalse(root.continueButton.isEnabled)
        XCTAssertEqual(root.passwordMatchLabel.text, R.string.localizable.backupCreatePasswordTooShort(
            "\(NSPredicate.backupPasswordMinimumLength)", preferredLanguages: controller.selectedLocale.rLanguages
        ))
        let validPassword = String(repeating: "a", count: NSPredicate.backupPasswordMinimumLength)
        password.changeValue(to: validPassword)
        confirmation.changeValue(to: "different")
        root.passwordTextField.animatedInputField.sendActions(for: .editingChanged)
        root.confirmPasswordTextField.animatedInputField.sendActions(for: .editingChanged)
        XCTAssertEqual(root.passwordMatchLabel.text, R.string.localizable.backupCreatePasswordNotMatched(preferredLanguages: controller.selectedLocale.rLanguages))
        XCTAssertFalse(root.continueButton.isEnabled)
        confirmation.changeValue(to: validPassword)
        root.confirmPasswordTextField.animatedInputField.sendActions(for: .editingChanged)
        XCTAssertEqual(root.confirmPasswordTextField.text, validPassword)
        XCTAssertFalse(root.continueButton.isEnabled)
        root.confirmButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.confirmButton.isChecked)
        XCTAssertTrue(root.continueButton.isEnabled)
        XCTAssertEqual(root.passwordMatchLabel.text, R.string.localizable.backupCreatePasswordMatched(preferredLanguages: controller.selectedLocale.rLanguages))
        root.continueButton.sendActions(for: .touchUpInside)
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.continues, 1)
        XCTAssertEqual(output.backs, 1)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(root.confirmPasswordTextField.animatedInputField))
        XCTAssertEqual(output.continues, 2)
        root.confirmButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(root.continueButton.isEnabled)
        controller.setPassword(isMatched: false)
        XCTAssertEqual(root.passwordMatchLabel.textColor, R.color.colorRed())
        XCTAssertNotNil(controller.target)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(300), UIConstants.bigOffset)
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    func testCreatePasswordEyeButtonsAndFieldFocusAreIndependent() throws {
        let output = CovJBackupCreateOutput()
        let controller = BackupCreatePasswordViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        for field in [root.passwordTextField, root.confirmPasswordTextField] {
            XCTAssertTrue(field.animatedInputField.textField.isSecureTextEntry)
            field.rightButton.sendActions(for: .touchUpInside)
            XCTAssertFalse(field.animatedInputField.textField.isSecureTextEntry)
            XCTAssertEqual(field.rightButton.image(for: .normal), R.image.iconNoEye())
            field.rightButton.sendActions(for: .touchUpInside)
            XCTAssertTrue(field.animatedInputField.textField.isSecureTextEntry)
            XCTAssertEqual(field.rightButton.image(for: .normal), R.image.iconEye())
        }
        root.confirmPasswordTextField.animatedInputField.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.confirmPasswordTextField.backgroundView.isHighlighted)
        XCTAssertFalse(root.passwordTextField.backgroundView.isHighlighted)
        root.passwordTextField.animatedInputField.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.passwordTextField.backgroundView.isHighlighted)
        XCTAssertFalse(root.confirmPasswordTextField.backgroundView.isHighlighted)
        controller.setPasswordConfirmationViewModel(InputViewModel(inputHandler: InputHandler()))
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(root.passwordTextField.animatedInputField))
        XCTAssertTrue(root.confirmPasswordTextField.backgroundView.isHighlighted)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(root.confirmPasswordTextField.animatedInputField))
        XCTAssertFalse(root.confirmPasswordTextField.backgroundView.isHighlighted)
        XCTAssertEqual(output.continues, 0)
    }

    func testCreatePasswordDelegateAcceptsUnboundAndRejectsDisabledInputs() {
        let controller = BackupCreatePasswordViewController(output: CovJBackupCreateOutput(), localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        let field = controller.rootView.passwordTextField.animatedInputField
        XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "a"))
        controller.setPasswordInputViewModel(InputViewModel(inputHandler: InputHandler(value: "preserved", enabled: false)))
        field.text = "unexpected"
        XCTAssertFalse(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "a"))
        XCTAssertEqual(field.text, "preserved")
        let confirm = controller.rootView.confirmPasswordTextField.animatedInputField
        let handler = InputHandler()
        controller.setPasswordConfirmationViewModel(InputViewModel(inputHandler: handler))
        XCTAssertTrue(controller.animatedTextField(confirm, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "value"))
        XCTAssertEqual(handler.value, "value")
    }

    func testRestorePasswordBindsWalletValidatesAndRoutesControls() throws {
        let output = CovJBackupPasswordOutput()
        let controller = BackupPasswordViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.applyLocalization()
        let root = controller.rootView
        let field = root.passwordTextField.animatedInputField
        controller.didReceive(walletName: "Travel")
        XCTAssertEqual(root.walletNameLabel.text, "Travel")
        XCTAssertEqual(output.loads, 1)
        XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "a"))
        let handler = InputHandler(predicate: NSPredicate.notEmpty)
        controller.setPasswordInputViewModel(InputViewModel(inputHandler: handler))
        XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "secret"))
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(root.passwordTextField.text, "secret")
        XCTAssertTrue(root.continueButton.isEnabled)
        root.continueButton.sendActions(for: .touchUpInside)
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.continues, 1)
        XCTAssertEqual(output.backs, 1)
        root.passwordTextField.rightButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(field.textField.isSecureTextEntry)
        root.passwordTextField.rightButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(field.textField.isSecureTextEntry)
        field.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.passwordTextField.backgroundView.isHighlighted)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(field))
        XCTAssertFalse(root.passwordTextField.backgroundView.isHighlighted)
        handler.changeValue(to: "")
        field.sendActions(for: .editingChanged)
        XCTAssertFalse(root.continueButton.isEnabled)
        controller.setPasswordInputViewModel(InputViewModel(inputHandler: InputHandler(value: "original", enabled: false)))
        field.text = "bad"
        XCTAssertFalse(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        XCTAssertEqual(field.text, "original")
        XCTAssertNotNil(controller.target)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(300), UIConstants.bigOffset)
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }
}
