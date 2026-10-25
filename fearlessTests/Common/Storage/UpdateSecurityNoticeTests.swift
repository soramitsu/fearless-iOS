import XCTest
@testable import fearless
import SoraKeystore
import UIKit

/// The security notice for people who update the app: decided at the first startup that knows
/// the stored wallets, shown once, and gone after the user closed it.
final class UpdateSecurityNoticeTests: XCTestCase {
    func testNotice_whenFreshInstall_thenNeverShown() {
        let settings = InMemorySettingsManager()

        let firstLaunch = UpdateSecurityNoticeTracker(settings: settings)
        firstLaunch.recordStartup(hadStoredWallets: false)
        XCTAssertFalse(firstLaunch.isPending)

        // The wallet created during onboarding does not turn the install into an update.
        let nextLaunch = UpdateSecurityNoticeTracker(settings: settings)
        nextLaunch.recordStartup(hadStoredWallets: true)
        XCTAssertFalse(nextLaunch.isPending)
    }

    func testNotice_whenUpdated_thenShownOnceAndNotAfterItWasClosed() {
        let settings = InMemorySettingsManager()

        let firstLaunch = UpdateSecurityNoticeTracker(settings: settings)
        firstLaunch.recordStartup(hadStoredWallets: true)
        XCTAssertTrue(firstLaunch.isPending)

        firstLaunch.acknowledge()
        XCTAssertFalse(firstLaunch.isPending)

        let nextLaunch = UpdateSecurityNoticeTracker(settings: settings)
        nextLaunch.recordStartup(hadStoredWallets: true)
        XCTAssertFalse(nextLaunch.isPending)
    }

    func testNotice_whenNotClosed_thenShownAtNextLaunch() {
        let settings = InMemorySettingsManager()

        UpdateSecurityNoticeTracker(settings: settings).recordStartup(hadStoredWallets: true)

        let nextLaunch = UpdateSecurityNoticeTracker(settings: settings)
        nextLaunch.recordStartup(hadStoredWallets: true)
        XCTAssertTrue(nextLaunch.isPending)
    }

    func testStartView_whenRouteIsValidated_thenRecordsWhetherWalletsWereStored() throws {
        // A store that could not be read decides nothing; the later startup that reads it does.
        let cases: [(RootStartupRouteValidation, pendingAfterLaterStartup: Bool)] = [
            (.ready(pincodeAvailable: true), true),
            (.ready(pincodeAvailable: false), true),
            (.unsupportedOnlyWithoutPincode, true),
            (.empty, false),
            (.unavailableWithoutPincode, true)
        ]

        for (validation, expectedPending) in cases {
            let settings = InMemorySettingsManager()

            try startView(after: validation, settings: settings)
            // By the next startup a wallet exists, created or restored after the first one.
            try startView(after: .ready(pincodeAvailable: true), settings: settings)

            XCTAssertEqual(
                UpdateSecurityNoticeTracker(settings: settings).isPending,
                expectedPending,
                "\(validation)"
            )
        }
    }

    func testStartView_whenRouteIsValidatedWithoutTracker_thenLeavesNoticeUndecided() throws {
        let settings = InMemorySettingsManager()
        let store = RootStartupRouteValidationStore()
        store.replace(with: .empty)
        let helper = StartViewHelper(
            keystore: InMemoryKeychain(),
            selectedWalletSettingsProvider: { SelectedWalletSettings.shared },
            userDefaultsStorage: settings,
            startupRouteValidationStore: store
        )

        _ = try helper.startView(onboardingConfig: nil)

        XCTAssertNil(settings.string(for: SettingsKey.updateSecurityNotice.rawValue))
    }

    func testSheet_whenCloseButtonHidden_thenActionsAreTheOnlyWayToClose() {
        let hidden = SheetAlertViewLayout(
            viewModel: SheetAlertPresentableViewModel(
                title: "Title",
                message: "Message",
                actions: [],
                closeAction: "OK",
                showsCloseButton: false
            )
        )
        XCTAssertNil(hidden.closeButton.superview)

        let shown = SheetAlertViewLayout(
            viewModel: SheetAlertPresentableViewModel(
                title: "Title",
                message: "Message",
                actions: [],
                closeAction: "OK"
            )
        )
        XCTAssertNotNil(shown.closeButton.superview)
    }

    func testNoticeSheet_whenBuilt_thenOneOkButtonIsTheOnlyWayToClose() {
        var closed = false
        let viewModel = SheetAlertPresentableViewModel.updateSecurityNotice(locale: Locale(identifier: "en")) {
            closed = true
        }

        XCTAssertEqual(viewModel.title, "Your mobile wallet is safe")
        XCTAssertTrue(viewModel.message?.hasPrefix("Fearless for iOS and Android was not affected") == true)
        XCTAssertEqual(viewModel.closeAction, "OK")
        XCTAssertTrue(viewModel.actions.isEmpty)
        XCTAssertFalse(viewModel.showsCloseButton)
        // A dismissal completion keeps taps on the blur and drags from closing the sheet.
        XCTAssertNotNil(viewModel.dismissCompletion)

        viewModel.dismissCompletion?()
        XCTAssertTrue(closed)
    }

    func testNoticeText_whenShippedLanguage_thenTranslated() throws {
        let english = try Self.noticeText(language: "en")
        XCTAssertEqual(english.title, "Your mobile wallet is safe")

        for language in ["id", "ja", "pt-PT", "ru", "tr", "vi", "zh-Hans"] {
            let translated = try Self.noticeText(language: language)
            XCTAssertNotEqual(translated.title, english.title, language)
            XCTAssertNotEqual(translated.message, english.message, language)
            XCTAssertTrue(translated.message.contains("2026"), language)
            XCTAssertTrue(translated.message.contains("Chrome"), language)
        }
    }

    // MARK: - Private

    private func startView(after validation: RootStartupRouteValidation, settings: SettingsManagerProtocol) throws {
        let store = RootStartupRouteValidationStore()
        store.replace(with: validation)
        let helper = StartViewHelper(
            keystore: InMemoryKeychain(),
            selectedWalletSettingsProvider: { SelectedWalletSettings.shared },
            userDefaultsStorage: settings,
            startupRouteValidationStore: store,
            updateSecurityNotice: UpdateSecurityNoticeTracker(settings: settings)
        )

        _ = try helper.startView(onboardingConfig: nil)
    }

    private static func noticeText(language: String) throws -> (title: String, message: String) {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), language)
        let bundle = try XCTUnwrap(Bundle(path: path), language)
        let missing = "<missing>"
        let title = bundle.localizedString(forKey: "update.security.notice.title", value: missing, table: nil)
        let message = bundle.localizedString(forKey: "update.security.notice.message", value: missing, table: nil)
        XCTAssertNotEqual(title, missing, language)
        XCTAssertNotEqual(message, missing, language)
        return (title, message)
    }
}
