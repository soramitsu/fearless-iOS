import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import SoraFoundation
import SoraUI
@testable import fearless

final class CovJAcctCreatePresenterSpy: AccountCreatePresenterProtocol {
    let flow: AccountCreateFlow
    var setups = 0
    var cryptoSelections = 0
    var infos = 0
    var substrateValidations = 0
    var ethereumValidations = 0
    var proceeds: [AccountCreateFlow?] = []
    var backups = 0

    init(flow: AccountCreateFlow = .wallet) {
        self.flow = flow
    }

    func setup() { setups += 1 }
    func selectSubstrateCryptoType() { cryptoSelections += 1 }
    func activateInfo() { infos += 1 }
    func validateSubstrate() { substrateValidations += 1 }
    func validateEthereum() { ethereumValidations += 1 }
    func proceed(withReplaced flow: AccountCreateFlow?) { proceeds.append(flow) }
    func didTapBackupButton() { backups += 1 }
}

final class CovJAcctCreateControllerTests: XCTestCase {
    private var languages: [String]? { LocalizationManager.shared.selectedLocale.rLanguages }

    private func make(flow: AccountCreateFlow = .wallet) throws -> (AccountCreateViewController, CovJAcctCreatePresenterSpy, UIWindow) {
        let presenter = CovJAcctCreatePresenterSpy(flow: flow)
        let controller = AccountCreateViewController(presenter: presenter)
        controller.localizationManager = LocalizationManager.shared
        let window = try CovJViewFixture.host(controller)
        return (controller, presenter, window)
    }

    private func pathModel(processor: TextProcessing? = nil, placeholder: String) -> AccountCreateViewModel {
        AccountCreateViewModel(
            inputHandler: InputHandler(predicate: .deriviationPathHardSoft, processor: processor), placeholder: placeholder
        )
    }

    func testTitlesInfoButtonAndActions() throws {
        let (controller, presenter, window) = try make()
        defer { window.isHidden = true }
        XCTAssertEqual(presenter.setups, 1)
        XCTAssertEqual(controller.title, R.string.localizable.accountCreateTitle(preferredLanguages: languages))
        let info = try XCTUnwrap(controller.navigationItem.rightBarButtonItem?.customView as? UIButton)
        XCTAssertEqual(info.accessibilityLabel, R.string.localizable.commonInfo(preferredLanguages: languages))
        info.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.infos, 1)

        controller.rootView.nextButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.proceeds.count, 1)
        XCTAssertNil(presenter.proceeds.first ?? nil)

        let crypto = controller.rootView.substrateCryptoTypeView.actionControl
        crypto.sendActions(for: .touchUpInside)
        XCTAssertTrue(crypto.isActivated)
        XCTAssertEqual(presenter.cryptoSelections, 1)
        controller.didCompleteCryptoTypeSelection()
        XCTAssertFalse(crypto.isActivated)

        let (backup, _, backupWindow) = try make(flow: .backup)
        defer { backupWindow.isHidden = true }
        XCTAssertEqual(backup.title, R.string.localizable.backupMnemonicTitle(preferredLanguages: languages))
    }

    func testValidationIconsAndFieldDelegates() throws {
        let (controller, presenter, window) = try make()
        defer { window.isHidden = true }
        let root = controller.rootView
        let substrate = pathModel(placeholder: DerivationPathConstants.hardSoftPlaceholder)
        let ethereum = pathModel(processor: NumbersAndSlashesProcessor(), placeholder: DerivationPathConstants.defaultEthereum)
        controller.bind(substrateViewModel: substrate)
        controller.bind(ethereumViewModel: ethereum)

        controller.didValidateSubstrateDerivationPath(.valid)
        controller.didValidateEthereumDerivationPath(.invalid)
        XCTAssertNotNil(root.substrateDerivationPathImage.image)
        XCTAssertNotNil(root.ethereumDerivationPathImage.image)
        controller.didValidateSubstrateDerivationPath(.none)
        controller.didValidateEthereumDerivationPath(.none)
        XCTAssertNil(root.substrateDerivationPathImage.image)
        XCTAssertNil(root.ethereumDerivationPathImage.image)

        controller.textFieldDidEndEditing(root.substrateDerivationPathField)
        controller.textFieldDidEndEditing(root.ethereumDerivationPathField)
        controller.textFieldDidEndEditing(UITextField())
        XCTAssertFalse(controller.textFieldShouldReturn(root.substrateDerivationPathField))
        XCTAssertFalse(controller.textFieldShouldReturn(root.ethereumDerivationPathField))
        XCTAssertFalse(controller.textFieldShouldReturn(UITextField()))
        XCTAssertEqual(presenter.substrateValidations, 2)
        XCTAssertEqual(presenter.ethereumValidations, 2)

        let start = NSRange(location: 0, length: 0)
        XCTAssertTrue(controller.textField(root.substrateDerivationPathField, shouldChangeCharactersIn: start, replacementString: "//1"))
        XCTAssertEqual(substrate.inputHandler.value, "//1")
        root.ethereumDerivationPathField.text = "q"
        XCTAssertFalse(controller.textField(root.ethereumDerivationPathField, shouldChangeCharactersIn: start, replacementString: "q"))
        XCTAssertEqual(root.ethereumDerivationPathField.text, "")
        XCTAssertTrue(controller.textField(UITextField(), shouldChangeCharactersIn: start, replacementString: "z"))

        controller.applyLocalization()
        XCTAssertEqual(
            root.ethereumDerivationPathLabel.text,
            R.string.localizable.example(DerivationPathConstants.defaultEthereum, preferredLanguages: languages)
        )
        XCTAssertEqual(
            root.substrateDerivationPathField.accessibilityLabel,
            R.string.localizable.substrateSecretDerivationPath(preferredLanguages: languages).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func testKeyboardAdaptation() throws {
        let (controller, _, window) = try make()
        defer { window.isHidden = true }
        let root = controller.rootView
        controller.viewDidLayoutSubviews()
        XCTAssertTrue(controller.shouldApplyKeyboardFrame)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(12), root.adaptiveCreate ? 0 : UIConstants.bigOffset)
        XCTAssertTrue(controller.target === root.keyboardAdoptableConstraint)

        root.contentView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 99, right: 0)
        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 0, width: 390, height: 300))
        XCTAssertEqual(root.contentView.scrollView.contentInset.bottom, root.adaptiveCreate ? 0 : 99)

        if root.adaptiveCreate {
            root.handleKeyboard(frame: CGRect(x: 0, y: 0, width: 390, height: 210))
            XCTAssertEqual(root.keyboardAdoptableConstraint?.layoutConstraints.first?.constant, -210)
        }
    }
}

final class CovJAcctCreateLayoutTests: XCTestCase {
    func testAdvancedToggleAndToolbarClose() throws {
        let layout = AccountCreateViewLayout(flow: .wallet)
        let window = try CovJViewFixture.host(layout)
        defer { window.isHidden = true }
        let expandable = try XCTUnwrap(CovJViewFixture.descendants(ExpandableActionControl.self, in: layout).first)
        let advanced = try XCTUnwrap(layout.substrateCryptoTypeView.superview)
        XCTAssertTrue(advanced.isHidden)

        expandable.sendActions(for: .touchUpInside)
        XCTAssertTrue(expandable.isActivated)
        XCTAssertFalse(advanced.isHidden)
        expandable.sendActions(for: .touchUpInside)
        XCTAssertFalse(expandable.isActivated)
        XCTAssertTrue(advanced.isHidden)

        let toolbar = try XCTUnwrap(layout.ethereumDerivationPathField.inputAccessoryView as? UIToolbar)
        let close = try XCTUnwrap(toolbar.items?.last)
        let action = try XCTUnwrap(close.action)
        XCTAssertTrue(UIApplication.shared.sendAction(action, to: close.target, from: close, for: nil))
        XCTAssertFalse(layout.ethereumDerivationPathField.isFirstResponder)
    }

    func testFlowSpecificButtons() {
        let model = UniqueChainModel(meta: AccountGenerator.generateMetaAccount(), chain: CovJFixture.chain())
        let chain = AccountCreateViewLayout(flow: .chain(model: model))
        XCTAssertTrue(chain.backupButton.isHidden)

        let backup = AccountCreateViewLayout(flow: .backup)
        let expandable = CovJViewFixture.descendants(ExpandableActionControl.self, in: backup).first
        XCTAssertEqual(expandable?.isHidden, true)
        XCTAssertFalse(backup.backupButton.isHidden)

        let wallet = AccountCreateViewLayout(flow: .wallet)
        XCTAssertFalse(wallet.backupButton.isHidden)
        XCTAssertTrue(wallet.buttonVStackView.arrangedSubviews.contains(wallet.backupButton))
    }
}

final class CovJAcctCreateRoutingTests: XCTestCase {
    private typealias PickerController = ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>

    private func request() throws -> MetaAccountImportMnemonicRequest {
        MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: CovJAcctImportHarness.phrase), username: "Routed",
            substrateDerivationPath: "", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519, defaultChainId: nil
        )
    }

    private func exercise(_ wireframe: AccountCreateWireframeProtocol, file: StaticString = #filePath, line: UInt = #line) throws {
        let confirmHost = try CovJHostedView(controller: CovJAcctCreateViewStub())
        defer { confirmHost.close() }
        let confirmView = try XCTUnwrap(confirmHost.controller as? CovJAcctCreateViewStub)
        wireframe.confirm(from: confirmView, flow: .wallet(try request()))
        XCTAssertTrue(confirmHost.top is AccountConfirmViewController, file: file, line: line)

        let backupHost = try CovJHostedView(controller: CovJAcctCreateViewStub())
        defer { backupHost.close() }
        wireframe.showBackupCreatePassword(request: try request(), from: backupHost)
        XCTAssertTrue(backupHost.top is BackupCreatePasswordViewController, file: file, line: line)

        let pickerHost = try CovJHostedView(controller: CovJAcctCreateViewStub())
        defer { pickerHost.close() }
        let pickerView = try XCTUnwrap(pickerHost.controller as? CovJAcctCreateViewStub)
        wireframe.presentCryptoTypeSelection(
            from: pickerView, availableTypes: [], selectedType: .ecdsa, delegate: nil, context: nil
        )
        XCTAssertNil(pickerHost.navigation.presentedViewController, file: file, line: line)
        wireframe.presentCryptoTypeSelection(
            from: pickerView, availableTypes: CryptoType.allCases, selectedType: .ecdsa, delegate: nil, context: nil
        )
        XCTAssertTrue(pickerHost.navigation.presentedViewController is PickerController, file: file, line: line)
    }

    func testOnboardingAddAndSwitchWireframesRoute() throws {
        try exercise(AccountCreateWireframe())
        try exercise(AddAccount.AccountCreateWireframe())
        try exercise(SwitchAccount.AccountCreateWireframe())
    }

    func testViewFactoriesBuildCreateControllers() throws {
        let model = UsernameSetupModel(username: "Factory")
        let onboarding = try XCTUnwrap(AccountCreateViewFactory.createViewForOnboarding(model: model, flow: .backup))
        let adding = try XCTUnwrap(AccountCreateViewFactory.createViewForAdding(model: model))
        let switching = try XCTUnwrap(AccountCreateViewFactory.createViewForSwitch(model: model))
        for view in [onboarding, adding, switching] {
            let controller = try XCTUnwrap(view.controller as? AccountCreateViewController)
            XCTAssertNotNil(controller.localizationManager)
            XCTAssertFalse(controller.isViewLoaded)
        }
    }
}
