import XCTest
import UIKit
import Kingfisher
import SoraFoundation
import SoraUI
@testable import fearless

final class CovJAcctImportPresenterSpy: AccountImportPresenterProtocol {
    let flow: AccountImportFlow
    var setups = 0
    var sourceSelections = 0
    var cryptoSelections = 0
    var uploads = 0
    var substrateValidations = 0
    var ethereumValidations = 0
    var proceeds = 0
    var inputs: [String] = []

    init(flow: AccountImportFlow = .wallet(step: .substrate)) {
        self.flow = flow
    }

    func setup() { setups += 1 }
    func selectSourceType() { sourceSelections += 1 }
    func selectCryptoType() { cryptoSelections += 1 }
    func activateUpload() { uploads += 1 }
    func validateSubstrateDerivationPath() { substrateValidations += 1 }
    func validateEthereumDerivationPath() { ethereumValidations += 1 }
    func proceed() { proceeds += 1 }
    func validateInput(value: String) { inputs.append(value) }
}

/// An icon that records where it was asked to load instead of fetching anything.
final class CovJAcctImageStub: ImageViewModelProtocol {
    private(set) var loads: [UIImageView] = []

    func loadImage(
        on imageView: UIImageView, targetSize _: CGSize, animated _: Bool, cornerRadius _: CGFloat,
        completionHandler _: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?
    ) {
        loads.append(imageView)
    }

    func loadImage(on imageView: UIImageView, targetSize _: CGSize, animated _: Bool, cornerRadius _: CGFloat) {
        loads.append(imageView)
    }

    func loadImage(on imageView: UIImageView, targetSize _: CGSize, animated _: Bool) { loads.append(imageView) }
    func loadImage(on imageView: UIImageView, placholder _: Placeholder?, targetSize _: CGSize, animated _: Bool) {
        loads.append(imageView)
    }

    func cancel(on _: UIImageView) {}
}

final class CovJAcctImportControllerTests: XCTestCase {
    private var languages: [String]? { LocalizationManager.shared.selectedLocale.rLanguages }

    private func makeController(
        flow: AccountImportFlow = .wallet(step: .substrate)
    ) throws -> (AccountImportViewController, CovJAcctImportPresenterSpy, UIWindow) {
        let presenter = CovJAcctImportPresenterSpy(flow: flow)
        let controller = AccountImportViewController(presenter: presenter)
        controller.localizationManager = LocalizationManager.shared
        let window = try CovJViewFixture.host(controller)
        return (controller, presenter, window)
    }

    private func pathModel(_ predicate: NSPredicate, processor: TextProcessing? = nil, placeholder: String) -> InputViewModel {
        InputViewModel(
            inputHandler: InputHandler(required: false, predicate: predicate, processor: processor),
            placeholder: placeholder
        )
    }

    func testTitleFollowsFlowAndLoadSetsUpPresenter() throws {
        let (wallet, walletPresenter, walletWindow) = try makeController()
        defer { walletWindow.isHidden = true }
        XCTAssertEqual(walletPresenter.setups, 1)
        XCTAssertEqual(wallet.title, R.string.localizable.importWallet(preferredLanguages: languages))

        let model = UniqueChainModel(meta: AccountGenerator.generateMetaAccount(), chain: CovJFixture.chain())
        let (chain, _, chainWindow) = try makeController(flow: .chain(model: model))
        defer { chainWindow.isHidden = true }
        XCTAssertEqual(chain.title, R.string.localizable.onboardingRestoreAccount(preferredLanguages: languages))

        chain.applyLocalization()
        XCTAssertEqual(chain.title, R.string.localizable.onboardingRestoreAccount(preferredLanguages: languages))
    }

    func testUniqueChainWarningAndPickerCompletionUpdateRootView() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        let icon = CovJAcctImageStub()

        controller.setUniqueChain(viewModel: UniqueChainViewModel(text: "Kusama", icon: icon))
        XCTAssertFalse(root.chainViewContainer.isHidden)
        XCTAssertEqual(root.chainView.actionControl.contentView.subtitleLabelView.text, "Kusama")
        XCTAssertEqual(icon.loads.count, 1)
        XCTAssertTrue(icon.loads.first === root.chainView.actionControl.contentView.subtitleImageView)

        controller.setUploadWarning(message: "No network in this file")
        XCTAssertEqual(root.warningLabel.text, "No network in this file")
        XCTAssertFalse(root.warningContainerView.isHidden)

        root.sourceTypeView.actionControl.activate(animated: false)
        root.substrateCryptoTypeView.actionControl.activate(animated: false)
        XCTAssertTrue(root.sourceTypeView.actionControl.isActivated)
        controller.didCompleteSourceTypeSelection()
        controller.didCompleteCryptoTypeSelection()
        XCTAssertFalse(root.sourceTypeView.actionControl.isActivated)
        XCTAssertFalse(root.substrateCryptoTypeView.actionControl.isActivated)
    }

    func testDerivationFieldsValidateOnEndEditingAndReturn() throws {
        let (controller, presenter, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        controller.bind(substrateViewModel: pathModel(.deriviationPathHardSoft, placeholder: "//hard/soft"))
        controller.bind(ethereumViewModel: pathModel(
            .deriviationPathHardSoft, processor: NumbersAndSlashesProcessor(), placeholder: DerivationPathConstants.defaultEthereum
        ))

        controller.textFieldDidEndEditing(root.substrateDerivationPathField)
        controller.textFieldDidEndEditing(root.ethereumDerivationPathField)
        controller.textFieldDidEndEditing(UITextField())
        XCTAssertEqual(presenter.substrateValidations, 1)
        XCTAssertEqual(presenter.ethereumValidations, 1)

        XCTAssertFalse(controller.textFieldShouldReturn(root.substrateDerivationPathField))
        XCTAssertFalse(controller.textFieldShouldReturn(root.ethereumDerivationPathField))
        XCTAssertFalse(controller.textFieldShouldReturn(UITextField()))
        XCTAssertEqual(presenter.substrateValidations, 2)
        XCTAssertEqual(presenter.ethereumValidations, 2)
        XCTAssertEqual(
            root.ethereumDerivationPathLabel.text,
            R.string.localizable.example(DerivationPathConstants.defaultEthereum, preferredLanguages: languages)
        )
    }

    func testDerivationFieldsFilterReplacementsAndResyncText() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        let substrate = pathModel(.deriviationPathHardSoft, placeholder: "//hard/soft")
        let ethereum = pathModel(.deriviationPathHardSoft, processor: NumbersAndSlashesProcessor(), placeholder: "//44")
        controller.bind(substrateViewModel: substrate)
        controller.bind(ethereumViewModel: ethereum)
        let start = NSRange(location: 0, length: 0)

        XCTAssertTrue(controller.textField(root.substrateDerivationPathField, shouldChangeCharactersIn: start, replacementString: "//1"))
        XCTAssertEqual(substrate.inputHandler.value, "//1")
        XCTAssertTrue(controller.textField(root.ethereumDerivationPathField, shouldChangeCharactersIn: start, replacementString: "//4"))
        root.ethereumDerivationPathField.text = "//4x"
        XCTAssertFalse(controller.textField(
            root.ethereumDerivationPathField, shouldChangeCharactersIn: NSRange(location: 3, length: 0), replacementString: "x"
        ))
        XCTAssertEqual(ethereum.inputHandler.value, "//4")
        XCTAssertEqual(root.ethereumDerivationPathField.text, "//4")
        XCTAssertTrue(controller.textField(UITextField(), shouldChangeCharactersIn: start, replacementString: "z"))

        root.substrateDerivationPathField.text = "stale"
        root.substrateDerivationPathField.sendActions(for: .editingChanged)
        XCTAssertEqual(root.substrateDerivationPathField.text, "//1")
        root.ethereumDerivationPathField.text = "stale"
        root.ethereumDerivationPathField.sendActions(for: .editingChanged)
        XCTAssertEqual(root.ethereumDerivationPathField.text, "//4")
    }

    func testTextViewReplacementValidatesInputAndReturnKeyEndsEditing() throws {
        let (controller, presenter, window) = try makeController()
        defer { window.isHidden = true }
        let textView = controller.rootView.textView
        let start = NSRange(location: 0, length: 0)

        XCTAssertFalse(controller.textView(textView, shouldChangeTextIn: start, replacementText: "word"))
        XCTAssertTrue(presenter.inputs.isEmpty)

        controller.setSource(type: .mnemonic, chainType: .both, selectable: true)
        let source = InputViewModel(inputHandler: InputHandler(value: "", normalizer: MnemonicTextNormalizer()), placeholder: "Phrase")
        controller.setSource(viewModel: source)
        XCTAssertEqual(controller.rootView.textPlaceholderLabel.text, "Phrase")
        XCTAssertEqual(textView.accessibilityLabel, "Phrase")

        XCTAssertFalse(controller.textView(textView, shouldChangeTextIn: start, replacementText: String.returnKey))
        XCTAssertTrue(presenter.inputs.isEmpty)
        XCTAssertTrue(controller.textView(textView, shouldChangeTextIn: start, replacementText: "bottom drive"))
        XCTAssertEqual(source.inputHandler.value, "bottom drive")
        XCTAssertEqual(presenter.inputs, [source.inputHandler.normalizedValue])
    }

    func testNameAndPasswordFieldsFilterThroughTheirModels() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        let username = InputViewModel(inputHandler: InputHandler(
            predicate: NSPredicate.notEmpty, processor: ByteLengthProcessor.username
        ))
        let password = InputViewModel(inputHandler: InputHandler(required: true))
        controller.setName(viewModel: username, visible: true)
        controller.setPassword(viewModel: password)
        let start = NSRange(location: 0, length: 0)
        let nameField = root.usernameTextField.animatedInputField

        XCTAssertTrue(controller.animatedTextField(nameField, shouldChangeCharactersIn: start, replacementString: "Bob"))
        XCTAssertEqual(username.inputHandler.value, "Bob")
        nameField.text = "Bob"
        let long = String(repeating: "w", count: 40)
        XCTAssertFalse(controller.animatedTextField(nameField, shouldChangeCharactersIn: NSRange(location: 3, length: 0), replacementString: long))
        XCTAssertEqual(username.inputHandler.value.count, 32)
        XCTAssertEqual(nameField.text, username.inputHandler.value)

        XCTAssertTrue(controller.animatedTextField(root.passwordTextField.animatedInputField, shouldChangeCharactersIn: start, replacementString: "pw"))
        XCTAssertEqual(password.inputHandler.value, "pw")
        XCTAssertTrue(controller.animatedTextField(AnimatedTextField(), shouldChangeCharactersIn: start, replacementString: "ignored"))
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(nameField))
    }

    func testKeyboardFrameChangesAdjustScrollInsetForFirstResponder() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        controller.view.layoutIfNeeded()
        controller.viewDidLayoutSubviews()
        XCTAssertTrue(controller.shouldApplyKeyboardFrame)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(10), root.adaptiveEntry ? 0 : UIConstants.bigOffset)
        XCTAssertTrue(controller.target === root.keyboardAdoptableConstraint)

        controller.setSource(type: .mnemonic, chainType: .both, selectable: true)
        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 0, width: 390, height: 280))
        XCTAssertEqual(root.contentView.scrollView.contentInset.bottom, 0)

        let focused = root.textView.becomeFirstResponder()
        defer { root.textView.resignFirstResponder() }
        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 0, width: 390, height: 280))
        XCTAssertEqual(root.contentView.scrollView.contentInset.bottom, root.adaptiveEntry || !focused ? 0 : 280)
        controller.updateWhileKeyboardFrameChanging(.zero)
        XCTAssertEqual(root.contentView.scrollView.contentInset.bottom, 0)
    }

    func testAdvancedSectionTogglesAndToolbarCloseResignsEthereumField() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        controller.setSource(type: .mnemonic, chainType: .both, selectable: true)
        XCTAssertTrue(root.advancedContainerView.isHidden)

        root.expandableControl.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.expandableControl.isActivated)
        XCTAssertFalse(root.advancedContainerView.isHidden)
        root.expandableControl.sendActions(for: .touchUpInside)
        XCTAssertFalse(root.expandableControl.isActivated)
        XCTAssertTrue(root.advancedContainerView.isHidden)

        let toolbar = try XCTUnwrap(root.ethereumDerivationPathField.inputAccessoryView as? UIToolbar)
        let close = try XCTUnwrap(toolbar.items?.last)
        XCTAssertEqual(close.title, R.string.localizable.commonClose(preferredLanguages: CovJFixture.locale.rLanguages))
        let action = try XCTUnwrap(close.action)
        XCTAssertTrue(UIApplication.shared.sendAction(action, to: close.target, from: close, for: nil))
        XCTAssertFalse(root.ethereumDerivationPathField.isFirstResponder)

        if root.adaptiveEntry {
            root.handleKeyboard(frame: CGRect(x: 0, y: 0, width: 390, height: 250))
            XCTAssertEqual(root.keyboardAdoptableConstraint?.layoutConstraints.first?.constant, -250)
        }
    }

    func testKeystoreSourceShowsUploadAndPasswordAndLocalizesCaptions() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        controller.setSource(type: .keystore, chainType: .ethereum, selectable: false)
        controller.setSource(viewModel: InputViewModel(inputHandler: InputHandler(value: "{\"a\":1}")))

        XCTAssertFalse(root.uploadViewContainer.isHidden)
        XCTAssertFalse(root.passwordContainerView.isHidden)
        XCTAssertTrue(root.textViewContainer.isHidden)
        XCTAssertEqual(root.uploadView.subtitle, "{\"a\":1}")
        XCTAssertEqual(root.uploadView.title, R.string.localizable.importEthereumRecoveryJson(preferredLanguages: languages))

        controller.applyLocalization()
        XCTAssertEqual(
            root.sourceTypeView.actionControl.contentView.subtitleLabelView.text,
            AccountImportSource.keystore.titleForLocale(LocalizationManager.shared.selectedLocale)
        )
        XCTAssertEqual(root.uploadView.title, R.string.localizable.importEthereumRecoveryJson(preferredLanguages: languages))
    }
}
