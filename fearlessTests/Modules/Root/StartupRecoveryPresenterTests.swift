import Cuckoo
@testable import fearless
import SoraFoundation
import SoraKeystore
import UIKit
import XCTest

final class StartupRecoveryPresenterTests: XCTestCase {
    func testUnavailableExistingPINCannotBecomeNewPINSetup() throws {
        let keystore = MockKeystoreProtocol()
        stub(keystore) { $0.checkKey(for: KeystoreTag.pincode.rawValue).thenThrow(KeystoreError.unexpectedFail) }
        let controller = try XCTUnwrap(PinViewFactory.createPinSetupView(keystore: keystore) as? PinSetupViewController)
        XCTAssertEqual(controller.mode, .securedInput)
        verify(keystore, times(0)).addKey(any(), with: any())
    }

    func testOnboardingAfterRecoveryVerifiesTheExistingPINInsteadOfReplacingIt() throws {
        let keystore = InMemoryKeychain()
        let original = Data("existing recovery authentication".utf8)
        try keystore.saveKey(original, with: KeystoreTag.pincode.rawValue)
        let controller = try XCTUnwrap(PinViewFactory.createPinSetupView(keystore: keystore) as? PinSetupViewController)
        XCTAssertEqual(controller.mode, .securedInput)
        XCTAssertEqual(try keystore.fetchKey(for: KeystoreTag.pincode.rawValue), original)
        try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)
        let freshController = try XCTUnwrap(PinViewFactory.createPinSetupView(keystore: keystore) as? PinSetupViewController)
        XCTAssertEqual(freshController.mode, .create)
    }

    func testMinimalRecoveryInteractorOnlyRetriesWithoutDeletingAnything() {
        let interactor = RecoveryRetryOnlyInteractor()
        interactor.recover(.restoreWalletAccess)
        XCTAssertEqual(interactor.requestedMigrations, [true])
    }

    func testEveryFailureOffersRetryEmergencyAccessAndPreviousDataWithoutWalletDetails() {
        for phase in [
            RootSetupPhase.languageMigration,
            .userStorageMigration,
            .substrateMigration,
            .substratePreflight,
            .selectedWalletOpening
        ] {
            let model = StartupRecoveryViewModel(
                failure: .init(
                    phase: phase,
                    incidentCode: .walletRecordRejected,
                    elapsedTime: 1,
                    recoveryAction: .retry
                ),
                consecutiveFailures: 1
            )
            XCTAssertTrue(model.actions.contains(.retry))
            XCTAssertTrue(model.actions.contains(.emergencyExport))
            XCTAssertTrue(model.actions.contains(.previousData))
            XCTAssertEqual(model.incidentCode, "WALLET_RECORD_REJECTED")
            XCTAssertFalse(model.message.contains("install the latest"))
        }
    }

    func testTransientNetworkFailureEscalatesOnlyAfterSecondAttempt() {
        let failure = RootSetupFailure(
            phase: .substratePreflight,
            incidentCode: .substratePreflightFailed,
            elapsedTime: 2,
            recoveryAction: .retry
        )
        XCTAssertFalse(StartupRecoveryViewModel(failure: failure, consecutiveFailures: 1).actions
            .contains(.freshNetworkData))
        XCTAssertTrue(StartupRecoveryViewModel(failure: failure, consecutiveFailures: 2).actions
            .contains(.freshNetworkData))
        let known = RootSetupFailure(
            phase: .substrateMigration,
            incidentCode: .substrateCompatibilityMissing,
            elapsedTime: 0,
            recoveryAction: .continueWithFreshNetworkData
        )
        XCTAssertTrue(StartupRecoveryViewModel(failure: known, consecutiveFailures: 1).actions
            .contains(.freshNetworkData))
    }

    func testLanguageAndWalletFailureEscalationAndHelpContainOnlyIncident() throws {
        let failure = RootSetupFailure(
            phase: .languageMigration,
            incidentCode: .languageMigrationFailed,
            elapsedTime: 0,
            recoveryAction: .retry
        )
        let model = StartupRecoveryViewModel(failure: failure, consecutiveFailures: 2)
        XCTAssertTrue(model.actions.contains(.continueInEnglish))
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(model.helpURL), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "body", value: "LANGUAGE_MIGRATION_FAILED")])
        let wallet = RootSetupFailure(
            phase: .userStorageMigration,
            incidentCode: .userStorageMigrationFailed,
            elapsedTime: 0,
            recoveryAction: .retry
        )
        XCTAssertTrue(StartupRecoveryViewModel(failure: wallet, consecutiveFailures: 2).actions
            .contains(.restoreWalletAccess))
    }

    func testRecoveryStringsExistInEveryShippedLocaleAndAvoidDestructiveAdvice() {
        let keys = [
            "title",
            "network_message",
            "wallet_message",
            "free_storage",
            "retry",
            "fresh_network",
            "restore_access",
            "english",
            "export",
            "previous_data",
            "help",
            "authenticate",
            "read_failed",
            "close",
            "share",
            "export_warning",
            "locked",
            "restore_access_warning",
            "continue",
            "advanced",
            "archive_message",
            "no_archives",
            "checking",
            "wallet_data",
            "network_data",
            "restore",
            "not_ready",
            "restore_warning",
            "restore_queued"
        ]
        for locale in ["en", "id", "ja", "pt", "pt-PT", "ru", "tr", "vi", "zh-Hans"] {
            for key in keys {
                let text = RecoveryText.string(key, locale: locale)
                XCTAssertNotEqual(text, "recovery." + key, "\(locale):\(key)")
                for forbidden in ["reinstall", "re-install", "install the latest", "delete the app", "update the app"] {
                    XCTAssertFalse(text.lowercased().contains(forbidden))
                }
            }
        }
    }

    @MainActor
    func testSuccessfulRecoveryResumesStartupAndReadableWalletImportDoesNotSetAside() {
        let wireframe = RecoveryRecordingWireframe()
        let interactor = RecoveryRecordingInteractor()
        let presenter = RootPresenter(
            localizationManager: LocalizationManager.shared,
            startViewHelper: RecoveryStartViewHelper()
        )
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.window = UIWindow()
        presenter.recoverAfterFailure(.freshNetworkData, phase: .substratePreflight)
        XCTAssertEqual(interactor.actions, [.freshNetworkData])
        presenter.didUpdateSetup(.ready)
        XCTAssertEqual(wireframe.mainCount, 1)
        presenter.recoverAfterFailure(.restoreWalletAccess, phase: .selectedWalletOpening)
        XCTAssertEqual(wireframe.mainCount, 2)
        XCTAssertEqual(interactor.actions, [.freshNetworkData], "Readable wallet rows must not be set aside for import")
    }

    @MainActor
    func testEmergencyPreviewClearsMaterialAndShareActionBeforeAppSnapshot() throws {
        let record = EmergencyWalletMaterial.Record(
            tag: "historical-entropy",
            bytesBase64: Data([1, 2, 3]).base64EncodedString()
        )
        let controller = EmergencyWalletMaterialViewController(material: .init(records: [record], unreadableTags: []))
        controller.loadViewIfNeeded()
        let text = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UITextView }.first)
        XCTAssertTrue(text.text.contains("historical-entropy"))
        XCTAssertNotNil(controller.navigationItem.rightBarButtonItem)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertFalse(text.text.contains("historical-entropy"))
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
    }

    @MainActor
    func testRecoveryActionsRemainReachableWithAccessibilityTextInSmallSceneWindow() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let failure = RootSetupFailure(
            phase: .substrateMigration,
            incidentCode: .substrateMigrationFailed,
            elapsedTime: 0,
            recoveryAction: .retry
        )
        let model = StartupRecoveryViewModel(failure: failure, consecutiveFailures: 2)
        let controller = StartupRecoveryViewController(model: model, handler: { _ in })
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        if #available(iOS 17.0, *) {
            controller.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        controller.view.layoutIfNeeded()
        let layout = try XCTUnwrap(controller.view as? StartupRecoveryViewLayout)
        let buttons = layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, model.actions.count)
        for button in buttons {
            XCTAssertGreaterThanOrEqual(button.bounds.height, 48)
            XCTAssertGreaterThan(button.bounds.width, 200)
            XCTAssertFalse(button.isHidden)
            let titleHeight = button.titleLabel?.sizeThatFits(CGSize(
                width: button.bounds.width,
                height: .greatestFiniteMagnitude
            )).height ?? 0
            XCTAssertGreaterThanOrEqual(
                button.bounds.height,
                ceil(titleHeight),
                "The action title must fit at accessibility text sizes"
            )
        }
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "recovery-320pt-maximum-text"
        attachment.lifetime = .keepAlways
        add(attachment)
        let scroll = try XCTUnwrap(layout.subviews.compactMap { $0 as? UIScrollView }.first)
        for button in buttons {
            scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
            layout.layoutIfNeeded()
            let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
            let target = window.hitTest(center, with: nil)
            XCTAssertTrue(target === button || target?.isDescendant(of: button) == true)
        }
        let actionsImage = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let actionsAttachment = XCTAttachment(image: actionsImage)
        actionsAttachment.name = "recovery-actions-320pt-maximum-text"
        actionsAttachment.lifetime = .keepAlways
        add(actionsAttachment)
    }
}

private struct RecoveryStartViewHelper: StartViewHelperProtocol {
    func startView(onboardingConfig _: OnboardingConfigWrapper?) throws -> StartView {
        .login
    }
}

private final class RecoveryRecordingInteractor: RootInteractorInputProtocol {
    var actions: [StartupRecoveryViewModel.Action] = []
    func recover(_ action: StartupRecoveryViewModel.Action) {
        actions.append(action)
    }

    func setup(runMigrations _: Bool) {}
    func fetchOnboardingConfig() async throws -> OnboardingConfigWrapper? {
        nil
    }
}

private final class RecoveryRecordingWireframe: RootWireframeProtocol {
    var mainCount = 0
    func showSplash(splashView _: ControllerBackedProtocol?, on _: UIWindow) {}
    func showLocalAuthentication(on _: UIWindow) {}
    func showMain(on _: UIWindow) {
        mainCount += 1
    }

    func showPincodeSetup(on _: UIWindow) {}
    func showBroken(on _: UIWindow) {}
    func showOnboarding(on _: UIWindow, with _: OnboardingConfigWrapper) {}
}

private final class RecoveryRetryOnlyInteractor: RootInteractorInputProtocol {
    var requestedMigrations: [Bool] = []
    func setup(runMigrations: Bool) {
        requestedMigrations.append(runMigrations)
    }

    func fetchOnboardingConfig() async throws -> OnboardingConfigWrapper? {
        nil
    }
}

@MainActor
final class StartupRecoveryPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]

    func testRootProgressAllLocalesAndTextSizes() async throws {
        for language in languages {
            for category in categories {
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let presenter = RootPresenter(
                    localizationManager: localization,
                    startViewHelper: RecoveryStartViewHelper()
                )
                let controller = RootViewController(presenter: presenter, localizationManager: localization)
                presenter.view = controller
                let window = try show(controller, category: category)
                defer { close(window); presenter.view = nil }
                presenter.didUpdateSetup(.running(.userStorageMigration))
                await settle(window)
                capture(window, name: "progress-\(language)-\(category.rawValue)-running")
                if FWAppearance.startupRecoveryRestyled {
                    XCTAssertFalse(
                        controller.rootView.statusLabel.isHidden,
                        "R7 must explain that startup is finishing"
                    )
                } else { XCTAssertTrue(controller.rootView.statusLabel.isHidden) }
                presenter.didUpdateSetup(.slow(.userStorageMigration, elapsedTime: 15))
                await settle(window)
                capture(window, name: "progress-\(language)-\(category.rawValue)-slow")
                let label = controller.rootView.statusLabel
                XCTAssertFalse(label.isHidden)
                if FWAppearance.startupRecoveryRestyled {
                    XCTAssertEqual(
                        label.font.pointSize,
                        UIFont
                            .fw(.bodyL, locale: localization.selectedLocale, compatibleWith: controller.traitCollection)
                            .pointSize
                    )
                    XCTAssertEqual(
                        label.text,
                        RecoveryText.string("startup_updating", locale: language) + "\n\n" + RecoveryText
                            .string("startup_keep_open", locale: language)
                    )
                    if let scroll = descendants(window).compactMap({ $0 as? UIScrollView }).first {
                        scroll.scrollRectToVisible(label.convert(label.bounds, to: scroll), animated: false)
                        await settle(window)
                        capture(window, name: "progress-\(language)-\(category.rawValue)-guidance-end")
                        let frame = label.convert(label.bounds, to: window)
                        XCTAssertLessThanOrEqual(frame.maxY, scroll.convert(scroll.bounds, to: window).maxY + 0.5)
                    }
                } else { XCTAssertEqual(label.font.pointSize, 15) }
                assertLabelFits(label, in: window)
                if FWAppearance.startupRecoveryRestyled, language != "en" {
                    XCTAssertNotEqual(
                        label.text,
                        "Updating/opening your wallet—keep Fearless open.",
                        "Selected language must be reflected in startup guidance"
                    )
                }
                controller.didReceive(state: .plain)
                XCTAssertTrue(label.isHidden)
            }
        }
    }

    func testStartupRecoveryAllLocalesAndTextSizes() async throws {
        let original = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = original }
        let cases: [(String, RootSetupFailure)] = [
            (
                "network",
                .init(
                    phase: .substratePreflight,
                    incidentCode: .substratePreflightFailed,
                    elapsedTime: 15,
                    recoveryAction: .retry
                )
            ),
            (
                "storage",
                .init(
                    phase: .userStorageMigration,
                    incidentCode: .insufficientStorage,
                    elapsedTime: 15,
                    recoveryAction: .freeStorage(requiredByteCount: 1_048_576)
                )
            ),
            (
                "language",
                .init(
                    phase: .languageMigration,
                    incidentCode: .languageMigrationFailed,
                    elapsedTime: 15,
                    recoveryAction: .retry
                )
            ),
        ]
        for language in languages {
            LocalizationManager.shared.selectedLocalization = language
            for category in categories {
                for (kind, failure) in cases {
                    let model = StartupRecoveryViewModel(failure: failure, consecutiveFailures: 2)
                    let controller = StartupRecoveryViewController(
                        model: model,
                        handler: { _ in XCTFail("Presentation baseline must not invoke recovery") }
                    )
                    let window = try show(controller, category: category)
                    defer { close(window) }
                    await settle(window)
                    let layout = try XCTUnwrap(controller.view as? StartupRecoveryViewLayout)
                    let scroll = try XCTUnwrap(layout.subviews.compactMap { $0 as? UIScrollView }.first)
                    let name = "recovery-\(kind)-\(language)-\(category.rawValue)"
                    capture(window, name: name + "-top")
                    let labels = layout.stack.arrangedSubviews.compactMap { $0 as? UILabel }
                    XCTAssertEqual(labels.first?.text, RecoveryText.string("title", locale: language))
                    XCTAssertTrue(model.message.contains(failure.incidentCode.rawValue))
                    for label in labels { assertLabelFits(label, in: window) }
                    let buttons = layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }
                    XCTAssertEqual(buttons.count, model.actions.count)
                    for (index, button) in buttons.enumerated() {
                        scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
                        await settle(window)
                        capture(window, name: name + "-action-\(index)")
                        let label = try XCTUnwrap(button.titleLabel)
                        assertLabelFits(label, in: button)
                        XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                        let frame = button.convert(button.bounds, to: window)
                        let viewport = scroll.convert(scroll.bounds, to: window)
                        XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY - 0.5)
                        XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY + 0.5)
                        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
                        XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
                    }
                }
            }
        }
    }

    func testStartupRecoveryLiveLocaleAndType() async throws {
        let original = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = original }
        LocalizationManager.shared.selectedLocalization = "en"
        let model = StartupRecoveryViewModel(
            failure: .init(phase: .substratePreflight, incidentCode: .substratePreflightFailed, elapsedTime: 15,
                           recoveryAction: .retry),
            consecutiveFailures: 2
        )
        let controller = StartupRecoveryViewController(
            model: model,
            handler: { _ in XCTFail("No real recovery in this fixture") }
        )
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let layout = try XCTUnwrap(controller.view as? StartupRecoveryViewLayout)
        let originalButtons = layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }
        LocalizationManager.shared.selectedLocalization = "ja"
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        await settle(window)
        capture(window, name: "recovery-live-en-to-ja-AX5")
        let title = try XCTUnwrap(layout.stack.arrangedSubviews.compactMap { $0 as? UILabel }.first)
        let expectedLocale = FWAppearance.startupRecoveryRestyled ? "ja" : "en"
        XCTAssertEqual(title.text, RecoveryText.string("title", locale: expectedLocale))
        XCTAssertEqual(layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }, originalButtons)
        XCTAssertEqual(originalButtons.first?.titleLabel?.text, RecoveryText.string("retry", locale: expectedLocale))
    }

    func testRecoveryLocaleChangeBeforeViewLoadsUsesCurrentLanguage() async throws {
        let original = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = original }
        LocalizationManager.shared.selectedLocalization = "en"
        let model = StartupRecoveryViewModel(
            failure: .init(phase: .languageMigration, incidentCode: .languageMigrationFailed,
                           elapsedTime: 15, recoveryAction: .retry),
            consecutiveFailures: 2
        )
        let controller = StartupRecoveryViewController(model: model) { _ in XCTFail("No real recovery") }
        XCTAssertFalse(controller.isViewLoaded)
        LocalizationManager.shared.selectedLocalization = "ru"
        XCTAssertFalse(controller.isViewLoaded)
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        await settle(window)
        let expected = FWAppearance.startupRecoveryRestyled ? "ru" : "en"
        XCTAssertEqual(controller.model.title, RecoveryText.string("title", locale: expected))
        XCTAssertEqual(controller.model.actions, model.actions)
        capture(window, name: "recovery-before-load-en-to-ru-AX5")
    }

    func testRootLiveLocaleTypeWidthAndPhase() async throws {
        guard FWAppearance.startupRecoveryRestyled else { return }
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = RootPresenter(localizationManager: localization, startViewHelper: RecoveryStartViewHelper())
        let controller = RootViewController(presenter: presenter, localizationManager: localization)
        presenter.view = controller
        let window = try show(controller, category: .large)
        defer { close(window); presenter.view = nil }
        presenter.didUpdateSetup(.running(.languageMigration))
        await settle(window)
        localization.selectedLocalization = "ja"
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        await settle(window)
        let label = controller.rootView.statusLabel
        XCTAssertEqual(
            label.text,
            RecoveryText.string("startup_updating", locale: "ja") + "\n\n" + RecoveryText
                .string("startup_keep_open", locale: "ja")
        )
        for width in [CGFloat(640), 320] {
            window.frame.size.width = width
            await settle(window)
            assertLabelFits(label, in: window)
            capture(window, name: "progress-live-ja-AX5-width-\(Int(width))")
        }
        presenter.didUpdateSetup(.running(.selectedWalletOpening))
        XCTAssertEqual(
            label.text,
            RecoveryText.string("startup_opening", locale: "ja") + "\n\n" + RecoveryText
                .string("startup_keep_open", locale: "ja")
        )
        let regular = label.font!
        if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .bold }
        await settle(window)
        let weight: (UIFont) -> CGFloat = { font in
            let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
            return (traits?[.weight] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
        }
        XCTAssertEqual(label.font.pointSize, regular.pointSize)
        XCTAssertGreaterThan(weight(label.font), weight(regular))
        capture(window, name: "progress-live-ja-AX5-opening-bold")
        if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .regular }
        await settle(window)
        XCTAssertEqual(label.font, regular)
        controller.didReceive(state: .plain)
        XCTAssertTrue(label.isHidden)
    }

    func testRecoveryLayoutRebindingKeepsExactActionCallbacks() async throws {
        let failure = RootSetupFailure(
            phase: .substratePreflight,
            incidentCode: .substratePreflightFailed,
            elapsedTime: 15,
            recoveryAction: .retry
        )
        let model = StartupRecoveryViewModel(failure: failure, consecutiveFailures: 2, locale: "en")
        let controller = UIViewController()
        let layout = StartupRecoveryViewLayout()
        var actions: [StartupRecoveryViewModel.Action] = []
        layout.bind(model: model) { actions.append($0) }
        controller.view = layout
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        await settle(window)
        let buttons = layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }
        for language in languages {
            let localized = model.localized(for: language)
            XCTAssertEqual(localized.actions, model.actions)
            XCTAssertEqual(localized.incidentCode, model.incidentCode)
            XCTAssertEqual(localized.helpURL, model.helpURL)
            layout.bind(model: localized) { _ in XCTFail("Rebinding must retain existing handlers") }
            await settle(window)
            XCTAssertEqual(layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }, buttons)
            let scroll = try XCTUnwrap(layout.subviews.compactMap { $0 as? UIScrollView }.first)
            for (index, button) in buttons.enumerated() {
                XCTAssertEqual(button.titleLabel?.text, model.actions[index].localizedTitle(locale: language))
                scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
                await settle(window)
                let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
                let hit = window.hitTest(point, with: nil)
                XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
                button.sendActions(for: .touchUpInside)
            }
        }
        XCTAssertEqual(actions, languages.flatMap { _ in model.actions })
        let different = StartupRecoveryViewModel(
            failure: .init(phase: .languageMigration, incidentCode: .languageMigrationFailed,
                           elapsedTime: 15, recoveryAction: .retry),
            consecutiveFailures: 2,
            locale: "vi"
        )
        var replacementActions: [StartupRecoveryViewModel.Action] = []
        layout.bind(model: different) { replacementActions.append($0) }
        await settle(window)
        let replacementButtons = layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(replacementButtons.count, different.actions.count)
        XCTAssertFalse(replacementButtons.first === buttons.first)
        for button in replacementButtons { button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(replacementActions, different.actions)
        XCTAssertEqual(actions, languages.flatMap { _ in model.actions })
    }

    private func show(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            window.rootViewController = controller
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return window
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        window.layoutIfNeeded()
    }

    private func assertLabelFits(
        _ label: UILabel,
        in parent: UIView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let fit = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertLessThanOrEqual(fit.height, label.bounds.height + 0.5, file: file, line: line)
        let frame = label.convert(label.bounds, to: parent)
        XCTAssertGreaterThanOrEqual(frame.minX, -0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, parent.bounds.width + 0.5, file: file, line: line)
    }

    private func close(_ window: UIWindow) { window.isHidden = true; window.rootViewController = nil }
    private func capture(_ window: UIWindow, name: String) {
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        })
        attachment
            .name = "startup-recovery-" + (FWAppearance.startupRecoveryRestyled ? "adaptive-" : "rollback-") + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let labels = descendants(window).compactMap { $0 as? UILabel }.map { label in
            [
                "text": label.text ?? "",
                "font": label.font.fontName,
                "pointSize": label.font.pointSize,
                "frame": NSCoder.string(for: label.convert(label.bounds, to: window)),
                "bounds": NSCoder.string(for: label.bounds),
            ] as [String: Any]
        }
        if let data = try? JSONSerialization.data(withJSONObject: labels, options: [.prettyPrinted, .sortedKeys]) {
            let metrics = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            metrics.name = (attachment.name ?? name) + "-metrics"
            metrics.lifetime = .keepAlways
            add(metrics)
        }
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
}
