@testable import fearless
import SoraFoundation
import SoraKeystore
import struct SSFModels.Currency
import SSFUtils
import UIKit
import XCTest

/// Turning biometrics on in Profile needs the PIN; turning them off does not.
@MainActor
final class ProfileBiometryAuthorizationTests: XCTestCase {
    private final class Secrets: SecretStoreManagerProtocol {
        var loads: [(DispatchQueue, (SecretDataRepresentable?) -> Void)] = []

        func loadSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
            loads.append((completionQueue, completionBlock))
        }

        func answer(_ index: Int, _ pin: String?) {
            let (queue, completion) = loads[index]
            queue.async { completion(pin) }
        }

        func saveSecret(_: SecretDataRepresentable, for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) {
            XCTFail("Authentication must not save a secret")
        }

        func removeSecret(for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) {
            XCTFail("Authentication must not remove a secret")
        }

        func checkSecret(for _: String, completionQueue _: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
            completionBlock(true)
        }

        func checkSecret(for _: String) -> Bool {
            true
        }
    }

    /// The enrollment the PIN holder vouched for, without LAContext or the device Keychain.
    private final class Enrollment: BiometryEnrollmentGuarding {
        private(set) var trustCalls = 0
        func isCurrentEnrollmentTrusted() -> Bool {
            true
        }

        func trustCurrentEnrollment() {
            trustCalls += 1
        }
    }

    private final class SceneNavigation: UINavigationController {
        var hasAppeared = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
        }
    }

    private final class Biometry: BiometryAuthProtocol {
        var availableBiometryType = AvailableBiometryType.faceId
        var requests = 0

        func authenticate(localizedReason _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) {
            requests += 1
        }
    }

    private final class ProfileData: ProfileInteractorInputProtocol {
        func setup(with output: ProfileInteractorOutputProtocol) {
            output.didReceive(wallet: AccountGenerator.generateMetaAccount())
            output.didRecieve(selectedCurrency: Currency.defaultCurrency())
        }

        func updateWallet(_: MetaAccountModel) {}
        func logout(completion: @escaping () -> Void) {
            XCTFail("Fixture must not log out"); completion()
        }

        func update(currency _: Currency) {}
    }

    /// Shows one Face ID switch that reflects the stored setting, as the production factory does.
    private final class ViewModels: ProfileViewModelFactoryProtocol {
        let settings: SettingsManagerProtocol

        init(settings: SettingsManagerProtocol) {
            self.settings = settings
        }

        func createProfileViewModel(
            from _: MetaAccountModel,
            locale _: Locale,
            language _: Language,
            currency _: Currency,
            balance _: WalletBalanceInfo?,
            missingAccountIssue _: [ChainIssue]
        ) -> ProfileViewModelProtocol {
            ProfileViewModel(
                profileUserViewModel: WalletsManagmentCellViewModel(isSelected: true, walletName: "Public fixture", fiatBalance: nil, dayChange: nil),
                profileOptionViewModel: [
                    ProfileOptionViewModel(
                        title: "Face ID",
                        icon: nil,
                        accessoryTitle: nil,
                        accessoryImage: nil,
                        accessoryType: .switcher(settings.biometryEnabled ?? false),
                        option: .biometry
                    )
                ],
                logoutViewModel: ProfileOptionViewModel(title: "Logout", icon: nil, accessoryTitle: nil, accessoryImage: nil, accessoryType: .arrow, option: nil)
            )
        }
    }

    private final class Factory {
        let settings = InMemorySettingsManager()
        let biometry = Biometry()
        let enrollment = Enrollment()
        let localization: LocalizationManager
        var attempts: [(secrets: Secrets, controller: PinSetupViewController)] = []

        init(biometryEnabled: Bool) throws {
            localization = try XCTUnwrap(LocalizationManager(localization: "en"))
            settings.biometryEnabled = biometryEnabled
        }

        func make(wireframe: ScreenAuthorizationWireframeProtocol, cancellable: Bool) -> PinSetupViewProtocol? {
            let secrets = Secrets()
            let interactor = LocalAuthInteractor(
                secretManager: secrets,
                settingsManager: settings,
                biometryAuth: biometry,
                locale: localization.selectedLocale,
                attemptLimiter: PincodeAttemptLimiter(keystore: InMemoryKeychain()),
                enrollmentGuard: enrollment
            )
            let view = PinViewFactory.createScreenAuthorizationView(
                with: wireframe,
                cancellable: cancellable,
                interactor: interactor,
                localizationManager: localization
            )
            if let controller = view as? PinSetupViewController {
                attempts.append((secrets, controller))
            }
            return view
        }
    }

    @MainActor
    private struct Fixture {
        let factory: Factory
        let profile: ProfileViewController
        let navigation: SceneNavigation
        let window: UIWindow

        func close() {
            navigation.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(descendants)
    }

    private func waitUntil(_ description: String, _ condition: () -> Bool) async throws {
        for _ in 0 ..< 100 {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail(description)
    }

    private func show(biometryEnabled: Bool) async throws -> Fixture {
        let factory = try Factory(biometryEnabled: biometryEnabled)
        let wireframe = ProfileWireframe(authorizationViewFactory: factory.make)
        let presenter = ProfilePresenter(
            viewModelFactory: ViewModels(settings: factory.settings),
            interactor: ProfileData(),
            wireframe: wireframe,
            logger: Logger.shared,
            settings: factory.settings,
            eventCenter: EventCenter(),
            localizationManager: factory.localization
        )
        let profile = ProfileViewController(presenter: presenter, iconGenerating: UniversalIconGenerator(), localizationManager: factory.localization)
        let navigation = SceneNavigation(rootViewController: profile)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        profile.loadViewIfNeeded()
        let fixture = Fixture(factory: factory, profile: profile, navigation: navigation, window: window)
        // UIKit drops a presentation started before the root has appeared.
        try await waitUntil("Profile has appeared") { navigation.hasAppeared }
        try await waitUntil("Profile shows the biometric switch") { biometrySwitch(fixture) != nil }
        return fixture
    }

    private func biometrySwitch(_ fixture: Fixture) -> UISwitch? {
        fixture.window.layoutIfNeeded()
        return descendants(fixture.profile.rootView.tableView).compactMap { $0 as? UISwitch }.first { !$0.isHidden }
    }

    private func flip(_ fixture: Fixture, on: Bool) throws {
        let toggle = try XCTUnwrap(biometrySwitch(fixture))
        toggle.setOn(on, animated: false)
        toggle.sendActions(for: .valueChanged)
    }

    private func pinScreen(_ fixture: Fixture) async throws -> (secrets: Secrets, controller: PinSetupViewController) {
        try await waitUntil("The PIN screen opens") {
            fixture.navigation.presentedViewController is PinSetupViewController && fixture.navigation.transitionCoordinator == nil
        }
        return try XCTUnwrap(fixture.factory.attempts.last)
    }

    func testTurningBiometricsOnNeedsTheRightPin() async throws {
        let fixture = try await show(biometryEnabled: false)
        defer { fixture.close() }
        try flip(fixture, on: true)
        let screen = try await pinScreen(fixture)
        XCTAssertEqual(fixture.factory.settings.biometryEnabled, false, "Nothing changes before the PIN is confirmed")
        XCTAssertEqual(fixture.factory.biometry.requests, 0, "Biometrics cannot confirm their own activation")

        screen.controller.presenter.submit(pin: "000000")
        screen.secrets.answer(0, "123456")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(fixture.factory.settings.biometryEnabled, false, "A wrong PIN does not turn biometrics on")
        XCTAssertTrue(fixture.navigation.presentedViewController === screen.controller)

        screen.controller.presenter.submit(pin: "123456")
        screen.secrets.answer(1, "123456")
        try await waitUntil("The right PIN turns biometrics on") {
            fixture.factory.settings.biometryEnabled == true && fixture.navigation.presentedViewController == nil
        }
        try await waitUntil("The switch shows biometrics on") { biometrySwitch(fixture)?.isOn == true }
        XCTAssertEqual(fixture.factory.enrollment.trustCalls, 1, "Only the correct PIN vouches for the enrollment")
        XCTAssertEqual(fixture.factory.biometry.requests, 0)
    }

    func testCancelledPinKeepsBiometricsOff() async throws {
        let fixture = try await show(biometryEnabled: false)
        defer { fixture.close() }
        try flip(fixture, on: true)
        let screen = try await pinScreen(fixture)
        screen.controller.presenter.cancel()
        try await waitUntil("Cancel closes the PIN screen") {
            fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil
        }
        XCTAssertEqual(fixture.factory.settings.biometryEnabled, false)
        try await waitUntil("The switch returns to off") { biometrySwitch(fixture)?.isOn == false }
    }

    func testTurningBiometricsOffNeedsNoPin() async throws {
        let fixture = try await show(biometryEnabled: true)
        defer { fixture.close() }
        XCTAssertEqual(biometrySwitch(fixture)?.isOn, true)
        try flip(fixture, on: false)
        XCTAssertEqual(fixture.factory.settings.biometryEnabled, false)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNil(fixture.navigation.presentedViewController)
        XCTAssertTrue(fixture.factory.attempts.isEmpty)
    }
}
