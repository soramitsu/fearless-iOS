@testable import fearless
import SoraFoundation
import IrohaCrypto
import UIKit
import XCTest

@MainActor
final class UsernameSetupTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]

    private final class NamePresenter: UsernameSetupPresenterProtocol {
        var loads = 0
        var proceeds = 0
        func didLoad(view: UsernameSetupViewProtocol) {
            loads += 1
            view.bindUsername(viewModel: SelectableViewModel(
                underlyingViewModel: InputViewModel(inputHandler: InputHandler(value: "Public wallet", required: true)),
                selectable: true
            ))
        }

        func proceed() { proceeds += 1 }
    }

    private final class ImportPresenter: AccountImportPresenterProtocol {
        let flow = AccountImportFlow.wallet(step: .substrate)
        var actions: [String] = []
        func setup() { actions.append("setup") }
        func selectSourceType() { actions.append("source") }
        func selectCryptoType() { actions.append("crypto") }
        func activateUpload() { actions.append("upload") }
        func validateSubstrateDerivationPath() { actions.append("substrate") }
        func validateEthereumDerivationPath() { actions.append("ethereum") }
        func proceed() { actions.append("proceed") }
        func validateInput(value _: String) { actions.append("input") }
    }

    func testActualWalletNameBaselineInAllLocalesAndTypeSizes() async throws {
        for language in languages {
            for category in categories {
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let presenter = NamePresenter()
                let controller = UsernameSetupViewController(presenter: presenter, localizationManager: localization)
                let window = try show(controller, category: category)
                defer { close(window) }
                await settle(window)
                XCTAssertEqual(presenter.loads, 1)
                XCTAssertEqual(controller.title, R.string.localizable.onboardingCreateWallet(preferredLanguages: [language]))
                XCTAssertEqual(controller.rootView.usernameTextField.text, "Public wallet")
                let captureName = "name-" + language + "-" + category.rawValue
                capture(window, name: captureName)
                if controller.rootView.adaptiveEntry {
                    assertInputFits(controller.rootView.usernameTextField, in: window)
                    assertLabelFits(controller.rootView.hintLabel)
                    reveal(controller.rootView.nextButton, in: controller.rootView.contentView.scrollView)
                    window.layoutIfNeeded()
                    assertActionReachable(controller.rootView.nextButton, in: window)
                    capture(window, name: captureName + "-action")
                }
                XCTAssertTrue(controller.rootView.nextButton.isEnabled)
                controller.rootView.nextButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(presenter.proceeds, 1)
            }
        }
    }

    func testActualImportModesBaselineInAllLocalesAndTypeSizes() async throws {
        for language in languages {
            for category in categories {
                for source in [AccountImportSource.mnemonic, .seed, .keystore, .legacyTonMnemonic] {
                    let localization = try XCTUnwrap(LocalizationManager(localization: language))
                    let presenter = ImportPresenter()
                    let controller = AccountImportViewController(presenter: presenter)
                    controller.localizationManager = localization
                    let window = try show(controller, category: category)
                    defer { close(window) }
                    configure(controller, source: source)
                    await settle(window)
                    XCTAssertEqual(controller.title, R.string.localizable.importWallet(preferredLanguages: [language]))
                    XCTAssertEqual(controller.rootView.sourceTypeView.actionControl.contentView.subtitleLabelView.text, source.titleForLocale(localization.selectedLocale))
                    let name = "import-" + String(describing: source) + "-" + language + "-" + category.rawValue
                    if controller.rootView.adaptiveEntry {
                        assertRowFits(controller.rootView.sourceTypeView, in: window)
                        assertInputFits(controller.rootView.usernameTextField, in: window)
                        if source == .keystore {
                            assertInputFits(controller.rootView.passwordTextField, in: window)
                            assertLabelFits(controller.rootView.uploadView.titleLabel)
                            if let subtitle = controller.rootView.uploadView.subtitleLabel { assertLabelFits(subtitle) }
                        }
                    }
                    capture(window, name: name + "-top")
                    let scroll = controller.rootView.contentView.scrollView
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                    window.layoutIfNeeded()
                    capture(window, name: name + "-bottom")
                    if source == .mnemonic || source == .seed {
                        UIView.performWithoutAnimation {
                            controller.rootView.expandableControl.sendActions(for: .touchUpInside)
                        }
                        await settle(window)
                        XCTAssertTrue(controller.rootView.expandableControl.isActivated)
                        XCTAssertFalse(controller.rootView.advancedContainerView.isHidden)
                        scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                        window.layoutIfNeeded()
                        capture(window, name: name + "-advanced")
                        if controller.rootView.adaptiveEntry {
                            let root = controller.rootView
                            for row in [root.substrateCryptoTypeView, root.ethereumCryptoTypeView] {
                                assertRowFits(row, in: window)
                                reveal(row, in: scroll)
                                window.layoutIfNeeded()
                                capture(window, name: name + "-advanced-row-" + (row === root.substrateCryptoTypeView ? "substrate" : "ethereum"))
                            }
                            for label in [root.substrateDerivationPathLabel, root.ethereumDerivationPathLabel] { assertLabelFits(label) }
                            for field in [root.substrateDerivationPathField, root.ethereumDerivationPathField] {
                                XCTAssertGreaterThanOrEqual(field.bounds.height + 1, field.font?.lineHeight ?? 0)
                                XCTAssertFalse(field.accessibilityLabel?.isEmpty ?? true)
                            }
                        }
                    }
                    if controller.rootView.adaptiveEntry {
                        reveal(controller.rootView.nextButton, in: scroll)
                        window.layoutIfNeeded()
                        assertActionReachable(controller.rootView.nextButton, in: window)
                        capture(window, name: name + "-action")
                    }
                    XCTAssertTrue(controller.rootView.nextButton.isEnabled)
                    controller.rootView.nextButton.sendActions(for: .touchUpInside)
                    XCTAssertEqual(presenter.actions.filter { $0 == "proceed" }.count, 1)
                    XCTAssertEqual(presenter.actions.filter { $0 == "setup" }.count, 1)
                }
            }
        }
    }

    func testActualEmptyImportFormsInAllLocalesAndTypeSizes() async throws {
        for language in languages {
            for category in categories {
                for source in [AccountImportSource.mnemonic, .seed, .keystore, .legacyTonMnemonic] {
                    let localization = try XCTUnwrap(LocalizationManager(localization: language))
                    let presenter = AccountImportPresenter(
                        wireframe: AccountImportWireframeProtocolStub(),
                        interactor: AccountImportInteractorInputProtocolStub(), flow: .wallet(step: .substrate)
                    )
                    presenter.localizationManager = localization
                    let controller = AccountImportViewController(presenter: presenter)
                    controller.localizationManager = localization
                    presenter.view = controller
                    let window = try show(controller, category: category)
                    defer { close(window) }
                    presenter.didReceiveAccountImport(metadata: MetaAccountImportMetadata(
                        availableSources: AccountImportSource.allCases, defaultSource: source,
                        availableCryptoTypes: CryptoType.allCases, defaultCryptoType: .sr25519
                    ))
                    await settle(window)
                    let root = controller.rootView
                    XCTAssertFalse(root.nextButton.isEnabled)
                    let name = "empty-import-" + String(describing: source) + "-" + language + "-" + category.rawValue
                    if root.adaptiveEntry {
                        assertInputFits(root.usernameTextField, in: window)
                        assertRowFits(root.sourceTypeView, in: window)
                        if source == .keystore {
                            assertInputFits(root.passwordTextField, in: window)
                            XCTAssertTrue(root.passwordTextField.animatedInputField.textField.isSecureTextEntry)
                            assertLabelFits(root.uploadView.titleLabel)
                            reveal(root.passwordTextField, in: root.contentView.scrollView)
                        } else {
                            XCTAssertFalse(root.textPlaceholderLabel.isHidden)
                            assertLabelFits(root.textPlaceholderLabel)
                            let placeholder = root.textPlaceholderLabel.convert(root.textPlaceholderLabel.bounds, to: root.textTriangularedView)
                            XCTAssertLessThanOrEqual(placeholder.maxY + 16, root.textTriangularedView.bounds.height + 1)
                            reveal(root.textTriangularedView, in: root.contentView.scrollView)
                        }
                        window.layoutIfNeeded()
                    }
                    capture(window, name: name)
                }
            }
        }
    }

    func testNativeNameEditingAndKeyboardViewport() async throws {
        for category in categories {
            let localization = try XCTUnwrap(LocalizationManager(localization: "ru"))
            let presenter = NamePresenter()
            let controller = UsernameSetupViewController(presenter: presenter, localizationManager: localization)
            let window = try show(controller, category: category)
            defer { close(window) }
            let model = InputViewModel(inputHandler: InputHandler(value: "", predicate: NSPredicate.notEmpty))
            controller.bindUsername(viewModel: SelectableViewModel(underlyingViewModel: model, selectable: true))
            let root = controller.rootView
            let editor = root.usernameTextField.animatedInputField.textField!
            XCTAssertFalse(root.nextButton.isEnabled)
            XCTAssertTrue(editor.becomeFirstResponder())
            await waitForLayoutAnimations(window)
            try enterText("Public wallet", into: editor)
            XCTAssertEqual(model.inputHandler.value, "Public wallet")
            XCTAssertEqual(editor.text, "Public wallet")
            XCTAssertTrue(root.nextButton.isEnabled)
            if root.adaptiveEntry {
                // Exercise the real adopter with a deterministic keyboard frame in the compact host.
                controller.apply(keyboardFrame: CGRect(x: 0, y: 308, width: 320, height: 260), keyboardHidden: false)
                await waitForLayoutAnimations(window)
                let scroll = root.contentView.scrollView
                XCTAssertEqual(scroll.convert(scroll.bounds, to: window).maxY, 308, accuracy: 1)
                XCTAssertEqual(scroll.contentInset.bottom, 0)
                reveal(editor, in: scroll)
                window.layoutIfNeeded()
                let editorFrame = editor.convert(editor.bounds, to: window)
                XCTAssertGreaterThanOrEqual(editorFrame.minY, scroll.convert(scroll.bounds, to: window).minY - 1)
                XCTAssertLessThanOrEqual(editorFrame.maxY, 309)
                XCTAssertTrue(editor.isFirstResponder)
                capture(window, name: "name-keyboard-editor-" + category.rawValue)
                reveal(root.nextButton, in: scroll)
                window.layoutIfNeeded()
                assertActionReachable(root.nextButton, in: window)
                XCTAssertLessThanOrEqual(root.nextButton.convert(root.nextButton.bounds, to: window).maxY, 309)
                capture(window, name: "name-keyboard-action-" + category.rawValue)
                let frame = root.nextButton.convert(root.nextButton.bounds, to: window)
                let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
                (hit as? UIControl)?.sendActions(for: .touchUpInside)
                XCTAssertEqual(presenter.proceeds, 1)
            }
            await settle(window)
        }
    }

    func testSecureImportEditorAndNativeSelectionCallbacks() async throws {
        for category in categories {
            let localization = try XCTUnwrap(LocalizationManager(localization: "ru"))
            let presenter = ImportPresenter()
            let controller = AccountImportViewController(presenter: presenter)
            controller.localizationManager = localization
            let window = try show(controller, category: category)
            defer { close(window) }
            configure(controller, source: .keystore)
            let name = input("")
            let password = input("")
            controller.setName(viewModel: name, visible: true)
            controller.setPassword(viewModel: password)
            await settle(window)
            let root = controller.rootView
            let nameEditor = root.usernameTextField.animatedInputField.textField!
            let passwordEditor = root.passwordTextField.animatedInputField.textField!
            XCTAssertFalse(root.nextButton.isEnabled)
            XCTAssertTrue(nameEditor.becomeFirstResponder())
            try enterText("Public wallet", into: nameEditor)
            XCTAssertEqual(name.inputHandler.value, "Public wallet")
            XCTAssertFalse(root.nextButton.isEnabled)
            XCTAssertTrue(passwordEditor.becomeFirstResponder())
            try enterText("public-password", into: passwordEditor)
            XCTAssertEqual(password.inputHandler.value, "public-password")
            XCTAssertTrue(passwordEditor.isSecureTextEntry)
            XCTAssertTrue(root.nextButton.isEnabled)
            let position = passwordEditor.offset(from: passwordEditor.beginningOfDocument, to: try XCTUnwrap(passwordEditor.selectedTextRange).start)
            localization.selectedLocalization = "ja"
            await waitForLayoutAnimations(window)
            XCTAssertTrue(passwordEditor.isFirstResponder)
            XCTAssertTrue(passwordEditor.isSecureTextEntry)
            XCTAssertEqual(passwordEditor.text, "public-password")
            XCTAssertEqual(passwordEditor.offset(from: passwordEditor.beginningOfDocument, to: try XCTUnwrap(passwordEditor.selectedTextRange).start), position)
            if root.adaptiveEntry {
                controller.apply(keyboardFrame: CGRect(x: 0, y: 308, width: 320, height: 260), keyboardHidden: false)
                await waitForLayoutAnimations(window)
                reveal(passwordEditor, in: root.contentView.scrollView)
                window.layoutIfNeeded()
                XCTAssertEqual(root.contentView.scrollView.convert(root.contentView.scrollView.bounds, to: window).maxY, 308, accuracy: 1)
                XCTAssertLessThanOrEqual(passwordEditor.convert(passwordEditor.bounds, to: window).maxY, 309)
                capture(window, name: "secure-import-keyboard-" + category.rawValue)
            }
            await settle(window)
            dispatchTouch(root.uploadView, in: root.contentView.scrollView, window: window)
            XCTAssertEqual(presenter.actions.filter { $0 == "upload" }.count, 1)
            dispatchTouch(root.sourceTypeView.actionControl, in: root.contentView.scrollView, window: window)
            XCTAssertEqual(presenter.actions.filter { $0 == "source" }.count, 1)
            controller.setSource(type: .mnemonic, chainType: .both, selectable: false)
            XCTAssertFalse(root.sourceTypeView.actionControl.isUserInteractionEnabled)
            root.expandableControl.sendActions(for: .touchUpInside)
            await settle(window)
            dispatchTouch(root.substrateCryptoTypeView.actionControl, in: root.contentView.scrollView, window: window)
            XCTAssertEqual(presenter.actions.filter { $0 == "crypto" }.count, 1)
            controller.setSelectedCrypto(model: SelectableViewModel(
                underlyingViewModel: TitleWithSubtitleViewModel(title: "sr25519", subtitle: "Schnorrkel"), selectable: false
            ))
            XCTAssertFalse(root.substrateCryptoTypeView.actionControl.isUserInteractionEnabled)
            capture(window, name: "import-native-callbacks-" + category.rawValue)
        }
    }

    private func dispatchTouch(_ control: UIControl, in scroll: UIScrollView, window: UIWindow) {
        reveal(control, in: scroll)
        window.layoutIfNeeded()
        let frame = control.convert(control.bounds, to: window).intersection(scroll.convert(scroll.bounds, to: window))
        XCTAssertFalse(frame.isEmpty)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true)
        if hit === control || hit?.isDescendant(of: control) == true { control.sendActions(for: .touchUpInside) }
    }

    func testLiveLanguageAndTypeReachBothEntryControllers() async throws {
        let nameLocalization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let name = UsernameSetupViewController(presenter: NamePresenter(), localizationManager: nameLocalization)
        let nameWindow = try show(name, category: .large)
        defer { close(nameWindow) }
        await settle(nameWindow)
        let nameFont = name.rootView.hintLabel.font.pointSize
        capture(nameWindow, name: "name-live-en-large")
        if #available(iOS 17.0, *) { nameWindow.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        nameLocalization.selectedLocalization = "ja"
        await settle(nameWindow)
        capture(nameWindow, name: "name-live-ja-AX5")
        XCTAssertEqual(name.title, R.string.localizable.onboardingCreateWallet(preferredLanguages: ["ja"]))
        XCTAssertEqual(name.rootView.hintLabel.text, R.string.localizable.usernameSetupHint(preferredLanguages: ["ja"]))
        XCTAssertGreaterThan(name.rootView.hintLabel.font.pointSize, nameFont)
        if name.rootView.adaptiveEntry {
            assertInputFits(name.rootView.usernameTextField, in: nameWindow)
            let regular = name.rootView.usernameTextField.animatedInputField.textFont
            if #available(iOS 17.0, *) { nameWindow.traitOverrides.legibilityWeight = .bold }
            await settle(nameWindow)
            XCTAssertNotEqual(name.rootView.usernameTextField.animatedInputField.textFont, regular)
            capture(nameWindow, name: "name-live-ja-AX5-bold")
        }

        let importLocalization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let imported = AccountImportViewController(presenter: ImportPresenter())
        imported.localizationManager = importLocalization
        let importWindow = try show(imported, category: .large)
        defer { close(importWindow) }
        configure(imported, source: .mnemonic)
        await settle(importWindow)
        let importFont = imported.rootView.usernameFooterLabel.font.pointSize
        capture(importWindow, name: "import-live-en-large")
        if #available(iOS 17.0, *) { importWindow.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        importLocalization.selectedLocalization = "ja"
        await settle(importWindow)
        capture(importWindow, name: "import-live-ja-AX5")
        XCTAssertEqual(imported.title, R.string.localizable.importWallet(preferredLanguages: ["ja"]))
        XCTAssertEqual(imported.rootView.sourceTypeView.actionControl.contentView.titleLabel.text, R.string.localizable.importSourcePickerTitle(preferredLanguages: ["ja"]))
        XCTAssertGreaterThan(imported.rootView.usernameFooterLabel.font.pointSize, importFont)
        if imported.rootView.adaptiveEntry {
            assertInputFits(imported.rootView.usernameTextField, in: importWindow)
            assertRowFits(imported.rootView.sourceTypeView, in: importWindow)
            XCTAssertEqual(
                imported.rootView.sourceTypeView.actionControl.contentView.subtitleLabelView.text,
                AccountImportSource.mnemonic.titleForLocale(Locale(identifier: "ja"))
            )
        }
    }

    func testRealPresenterLocaleRefreshPreservesDraftInputsAndExpansion() async throws {
        for source in [AccountImportSource.mnemonic, .seed, .keystore, .legacyTonMnemonic] {
            let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
            let presenter = AccountImportPresenter(
                wireframe: AccountImportWireframeProtocolStub(),
                interactor: AccountImportInteractorInputProtocolStub(), flow: .wallet(step: .substrate)
            )
            presenter.localizationManager = localization
            let controller = AccountImportViewController(presenter: presenter)
            controller.localizationManager = localization
            presenter.view = controller
            let window = try show(controller, category: .large)
            defer { close(window) }
            presenter.didReceiveAccountImport(metadata: MetaAccountImportMetadata(
                availableSources: AccountImportSource.allCases, defaultSource: source,
                availableCryptoTypes: CryptoType.allCases, defaultCryptoType: .sr25519
            ))
            let sourceModel = try XCTUnwrap(presenter.sourceViewModel)
            let nameModel = try XCTUnwrap(presenter.usernameViewModel)
            sourceModel.inputHandler.changeValue(to: source == .keystore ? "public.json" : "public draft")
            nameModel.inputHandler.changeValue(to: "Draft wallet")
            presenter.passwordViewModel?.inputHandler.changeValue(to: "public password")
            presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "//Draft")
            presenter.ethereumDerivationPathViewModel?.inputHandler.changeValue(to: "m/44'/60'/0'/0/7")
            controller.setSource(viewModel: sourceModel)
            controller.setName(viewModel: nameModel, visible: true)
            if let model = presenter.passwordViewModel { controller.setPassword(viewModel: model) }
            if let model = presenter.substrateDerivationPathViewModel { controller.bind(substrateViewModel: model) }
            if let model = presenter.ethereumDerivationPathViewModel { controller.bind(ethereumViewModel: model) }
            if !controller.rootView.expandableControl.isHidden {
                UIView.performWithoutAnimation { controller.rootView.expandableControl.sendActions(for: .touchUpInside) }
            }
            await settle(window)
            let sourceValue = sourceModel.inputHandler.value
            let passwordValue = presenter.passwordViewModel?.inputHandler.value
            let substrateValue = presenter.substrateDerivationPathViewModel?.inputHandler.value
            let ethereumValue = presenter.ethereumDerivationPathViewModel?.inputHandler.value
            let expanded = controller.rootView.expandableControl.isActivated
            localization.selectedLocalization = "ja"
            await settle(window)
            XCTAssertEqual(presenter.sourceViewModel?.inputHandler.value, sourceValue)
            XCTAssertEqual(presenter.usernameViewModel?.inputHandler.value, "Draft wallet")
            XCTAssertEqual(presenter.passwordViewModel?.inputHandler.value, passwordValue)
            XCTAssertEqual(presenter.substrateDerivationPathViewModel?.inputHandler.value, substrateValue)
            XCTAssertEqual(presenter.ethereumDerivationPathViewModel?.inputHandler.value, ethereumValue)
            XCTAssertTrue((presenter.sourceViewModel?.inputHandler as AnyObject) === (sourceModel.inputHandler as AnyObject))
            XCTAssertEqual(controller.rootView.expandableControl.isActivated, expanded)
            XCTAssertEqual(controller.rootView.usernameTextField.text, "Draft wallet")
            XCTAssertTrue(controller.rootView.passwordTextField.animatedInputField.textField.isSecureTextEntry)
            capture(window, name: "real-presenter-locale-" + String(describing: source))
        }
    }

    func testWrappingActionImmediatelyReflectsLoading() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = UsernameSetupViewController(presenter: NamePresenter(), localizationManager: localization)
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let button = controller.rootView.nextButton
        let label = try XCTUnwrap(button.wrappingLabel)
        button.set(loading: true)
        XCTAssertTrue(label.isHidden)
        XCTAssertFalse(button.accessibilityActivate())
        button.set(loading: false)
        XCTAssertFalse(label.isHidden)
        XCTAssertTrue(button.imageWithTitleView?.isHidden == true)
        button.set(enabled: false)
        XCTAssertFalse(button.accessibilityActivate())
    }

    func testEmptyNativeEditorRemainsVisibleAfterEndingEditing() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = UsernameSetupViewController(presenter: NamePresenter(), localizationManager: localization)
        let window = try show(controller, category: .large)
        defer { close(window) }
        let model = InputViewModel(inputHandler: InputHandler(value: "", predicate: NSPredicate.notEmpty))
        controller.bindUsername(viewModel: SelectableViewModel(underlyingViewModel: model, selectable: true))
        let editor = controller.rootView.usernameTextField.animatedInputField.textField!
        XCTAssertTrue(editor.becomeFirstResponder())
        try await Task.sleep(nanoseconds: 250_000_000)
        editor.resignFirstResponder()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(editor.isHidden, !controller.rootView.adaptiveEntry)
        if !controller.rootView.adaptiveEntry {
            XCTAssertFalse(controller.rootView.usernameTextField.animatedInputField.title?.isEmpty ?? true)
        }
        XCTAssertFalse(controller.rootView.nextButton.isEnabled)
        capture(window, name: "empty-editor-after-resigning")
    }

    func testActiveSourceEditorSurvivesPresenterLocaleRefresh() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = AccountImportPresenter(
            wireframe: AccountImportWireframeProtocolStub(),
            interactor: AccountImportInteractorInputProtocolStub(), flow: .wallet(step: .substrate)
        )
        presenter.localizationManager = localization
        let controller = AccountImportViewController(presenter: presenter)
        controller.localizationManager = localization
        presenter.view = controller
        let window = try show(controller, category: .large)
        defer { close(window) }
        presenter.didReceiveAccountImport(metadata: MetaAccountImportMetadata(
            availableSources: AccountImportSource.allCases, defaultSource: .mnemonic,
            availableCryptoTypes: CryptoType.allCases, defaultCryptoType: .sr25519
        ))
        let model = try XCTUnwrap(presenter.sourceViewModel)
        model.inputHandler.changeValue(to: "public fixture source draft")
        controller.setSource(viewModel: model)
        let editor = controller.rootView.textView
        reveal(editor, in: controller.rootView.contentView.scrollView)
        XCTAssertTrue(editor.becomeFirstResponder())
        editor.selectedRange = NSRange(location: 7, length: 7)
        try await Task.sleep(nanoseconds: 250_000_000)
        let range = editor.selectedRange
        localization.selectedLocalization = "ja"
        for _ in 0 ..< 3 { await Task.yield() }
        window.layoutIfNeeded()
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(editor.selectedRange, range)
        XCTAssertEqual(editor.text, "public fixture source draft")
        XCTAssertTrue((presenter.sourceViewModel?.inputHandler as AnyObject) === (model.inputHandler as AnyObject))
        capture(window, name: "active-source-editor-locale")
        if controller.rootView.adaptiveEntry {
            controller.apply(keyboardFrame: CGRect(x: 0, y: 308, width: 320, height: 260), keyboardHidden: false)
            await waitForLayoutAnimations(window)
            let scroll = controller.rootView.contentView.scrollView
            reveal(editor, in: scroll)
            window.layoutIfNeeded()
            XCTAssertEqual(scroll.convert(scroll.bounds, to: window).maxY, 308, accuracy: 1)
            let frame = editor.convert(editor.bounds, to: window)
            XCTAssertGreaterThanOrEqual(frame.minY, scroll.convert(scroll.bounds, to: window).minY - 1)
            XCTAssertLessThanOrEqual(frame.maxY, 309)
            XCTAssertTrue(editor.isFirstResponder)
            XCTAssertEqual(editor.selectedRange, range)
            capture(window, name: "active-source-keyboard-viewport")
        }
    }

    func testNameActionHitTestingAfterKeyboardSettles() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = UsernameSetupViewController(presenter: NamePresenter(), localizationManager: localization)
        let window = try show(controller, category: .large)
        defer { close(window) }
        window.endEditing(true)
        try await Task.sleep(nanoseconds: 350_000_000)
        reveal(controller.rootView.nextButton, in: controller.rootView.contentView.scrollView)
        window.layoutIfNeeded()
        attachHitHierarchy(controller.rootView.nextButton, in: window, name: "after-350ms")
        await waitForLayoutAnimations(window)
        reveal(controller.rootView.nextButton, in: controller.rootView.contentView.scrollView)
        window.layoutIfNeeded()
        attachHitHierarchy(controller.rootView.nextButton, in: window, name: "after-animation")
        assertActionReachable(controller.rootView.nextButton, in: window)
    }

    private func attachHitHierarchy(_ button: TriangularedButton, in window: UIWindow, name: String) {
        var nodes: [String] = []
        var current: UIView? = button
        let frame = button.convert(button.bounds, to: window)
        let point = CGPoint(x: frame.midX, y: frame.midY)
        while let view = current {
            let local = view.convert(point, from: window)
            let hit = view.hitTest(local, with: nil)
            nodes.append("\(type(of: view)): bounds=\(view.bounds), frame=\(view.frame), local=\(local), enabled=\(view.isUserInteractionEnabled), hidden=\(view.isHidden), alpha=\(view.alpha), animations=\(view.layer.animationKeys() ?? []), hit=\(String(describing: hit.map { type(of: $0) }))")
            current = view.superview
        }
        let attachment = XCTAttachment(string: nodes.joined(separator: "\n"))
        attachment.name = "entry-hit-hierarchy-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func enterText(_ text: String, into editor: UITextField) throws {
        // insertText does not ask UITextFieldDelegate for validation. Reproduce
        // UIKit's delegate → text insertion → editingChanged event sequence.
        let range = NSRange(location: (editor.text ?? "").utf16.count, length: 0)
        let allowed = editor.delegate?.textField?(editor, shouldChangeCharactersIn: range, replacementString: text) ?? true
        XCTAssertTrue(allowed)
        if allowed { editor.insertText(text) }
    }

    private func assertLabelFits(_ label: UILabel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(label.bounds.width, 0, file: file, line: line)
        let fitting = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 1, label.text ?? "", file: file, line: line)
    }

    private func assertInputFits(_ input: CommonInputView, in window: UIWindow) {
        assertLabelFits(input.captionLabel)
        let editor = input.animatedInputField.textField!
        XCTAssertEqual(editor.font?.pointSize ?? 0, UIFont.fw(.bodyL, compatibleWith: window.traitCollection).pointSize, accuracy: 0.1)
        XCTAssertEqual(input.captionLabel.font.pointSize, UIFont.fw(.bodyS, compatibleWith: window.traitCollection).pointSize, accuracy: 0.1)
        let caption = input.captionLabel.convert(input.captionLabel.bounds, to: input)
        let value = editor.convert(editor.bounds, to: input)
        XCTAssertLessThanOrEqual(caption.maxY, value.minY)
        XCTAssertGreaterThanOrEqual(editor.bounds.height + 1, editor.font?.lineHeight ?? 0)
        XCTAssertLessThanOrEqual(value.maxY, input.bounds.height + 1)
        XCTAssertFalse(editor.isHidden)
        XCTAssertEqual(editor.accessibilityLabel, input.title)
    }

    private func assertRowFits(_ row: BorderedSubtitleActionView, in window: UIWindow) {
        let title = row.actionControl.contentView.titleLabel
        let subtitle = row.actionControl.contentView.subtitleLabelView
        XCTAssertEqual(subtitle.font.pointSize, UIFont.fw(.bodyL, compatibleWith: window.traitCollection).pointSize, accuracy: 0.1)
        assertLabelFits(title)
        assertLabelFits(subtitle)
        XCTAssertLessThanOrEqual(title.convert(title.bounds, to: row).maxY, subtitle.convert(subtitle.bounds, to: row).minY)
        XCTAssertLessThanOrEqual(subtitle.convert(subtitle.bounds, to: row).maxY, row.bounds.height + 1)
    }

    private func reveal(_ view: UIView, in scroll: UIScrollView) {
        view.window?.layoutIfNeeded()
        scroll.layoutIfNeeded()
        view.layoutIfNeeded()
        view.window?.layoutIfNeeded()
        scroll.scrollRectToVisible(view.convert(view.bounds, to: scroll), animated: false)
    }

    private func assertActionReachable(_ button: TriangularedButton, in window: UIWindow) {
        guard let label = button.wrappingLabel else { return XCTFail("Missing adaptive action title") }
        assertLabelFits(label)
        XCTAssertEqual(label.font.pointSize, UIFont.fw(.labelL, compatibleWith: window.traitCollection).pointSize, accuracy: 0.1)
        let frame = button.convert(button.bounds, to: window)
        XCTAssertGreaterThanOrEqual(frame.minY, 0)
        XCTAssertLessThanOrEqual(frame.maxY, window.bounds.maxY + 1)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(
            hit === button || hit?.isDescendant(of: button) == true,
            "hit=\(String(describing: hit.map { type(of: $0) })); frame=\(frame); scroll=\(String(describing: button.superview?.superview?.frame))"
        )
    }

    private func configure(_ controller: AccountImportViewController, source: AccountImportSource) {
        // Public presentation fixtures only. No real presenter, keychain, file upload or import operation runs.
        controller.show(chainType: .both)
        controller.setSource(type: source, chainType: .both, selectable: true)
        controller.setName(viewModel: input("Public wallet"), visible: true)
        controller.setPassword(viewModel: input("public-password-fixture"))
        let value: String
        switch source {
        case .keystore: value = "public-wallet.json"
        case .seed: value = "0x" + String(repeating: "11", count: 32)
        case .mnemonic: value = String(repeating: "abandon ", count: 11) + "about"
        case .legacyTonMnemonic: value = String(repeating: "public fixture ", count: 12)
        }
        controller.setSource(viewModel: input(value))
        controller.bind(substrateViewModel: input("//Alice", placeholder: "//Alice"))
        controller.bind(ethereumViewModel: input("m/44'/60'/0'/0/0", placeholder: "m/44'/60'/0'/0/0"))
        controller.setSelectedCrypto(model: SelectableViewModel(
            underlyingViewModel: TitleWithSubtitleViewModel(title: "sr25519", subtitle: "Schnorrkel"), selectable: true
        ))
    }

    private func input(_ value: String, placeholder: String = "") -> InputViewModelProtocol {
        InputViewModel(inputHandler: InputHandler(value: value, required: true), placeholder: placeholder)
    }

    private func show(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            window.rootViewController = FearlessNavigationController(rootViewController: controller)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return window
    }

    private func settle(_ window: UIWindow) async {
        window.endEditing(true)
        await waitForLayoutAnimations(window)
    }

    private func waitForLayoutAnimations(_ window: UIWindow) async {
        // UIKit installs the keyboard transition on the next turn. Preserve the
        // real animation and wait for its layout layers, with a bounded timeout.
        try? await Task.sleep(nanoseconds: 100_000_000)
        for _ in 0 ..< 60 {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            let moving = descendants(window).contains { view in
                (view.layer.animationKeys() ?? []).contains { $0.hasPrefix("bounds") || $0.hasPrefix("position") }
            }
            if !moving { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Entry layout animation did not finish within 3 seconds")
    }

    private func close(_ window: UIWindow) {
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let picture = XCTAttachment(image: image)
        picture.name = "entry-baseline-320x568-" + name
        picture.lifetime = .keepAlways
        add(picture)
        let metrics = descendants(window).compactMap { view -> String? in
            if let label = view as? UILabel {
                return "label=\(label.text ?? ""); font=\(label.font.fontName); size=\(label.font.pointSize); hidden=\(label.isHidden); frame=\(label.convert(label.bounds, to: window)); fitting=\(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)))"
            }
            if let field = view as? UITextField {
                return "input=\(field.accessibilityLabel ?? ""); font=\(field.font?.fontName ?? ""); size=\(field.font?.pointSize ?? 0); frame=\(field.convert(field.bounds, to: window))"
            }
            return nil
        }.joined(separator: "\n")
        let diagnostic = XCTAttachment(string: metrics)
        diagnostic.name = "entry-baseline-metrics-" + name
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }
}
