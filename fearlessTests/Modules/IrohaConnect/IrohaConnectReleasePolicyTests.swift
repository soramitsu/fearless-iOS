import CryptoKit
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

/// IOSUX-1: IrohaConnect is hidden and hard-disabled in release builds. The wallet
/// would otherwise sign opaque dApp bytes with the key that controls SORA Nexus funds.
final class IrohaConnectReleasePolicyTests: XCTestCase {
    private enum SessionFactoryError: Error {
        case unexpectedCall
    }

    // MARK: - Policy

    func testProductionPolicy_isDisabled() {
        XCTAssertFalse(IrohaConnectReleasePolicy.production.isEnabled)
    }

    // MARK: - Profile

    func testProfileOptions_whenPolicyDisabled_thenNoIrohaConnectRow() {
        let defaultOptions = makeProfileOptions(factory: makeProfileViewModelFactory())
        let productionOptions = makeProfileOptions(factory: makeProfileViewModelFactory(policy: .production))

        XCTAssertFalse(defaultOptions.contains(.irohaConnect))
        XCTAssertFalse(productionOptions.contains(.irohaConnect))
        XCTAssertTrue(defaultOptions.contains(.walletConnect))
        XCTAssertTrue(defaultOptions.contains(.tonConnect))
    }

    #if DEBUG
        func testProfileOptions_whenPolicyEnabledForTests_thenIrohaConnectRowIsBuilt() {
            // Negative control: the row exists and is only filtered by the policy.
            let options = makeProfileOptions(factory: makeProfileViewModelFactory(policy: .enabledForTests))

            XCTAssertTrue(options.contains(.irohaConnect))
        }
    #endif

    // MARK: - Deep links, QR and landing

    func testURLHandler_whenPolicyDisabled_thenConsumesURLAndPresentsUnavailableWithoutSession() throws {
        let notice = UnavailableNoticeSpy()
        var sessionFactoryCalls = 0
        let coordinator = makeCoordinator(notice: notice) { _ in
            sessionFactoryCalls += 1
            throw SessionFactoryError.unexpectedCall
        }
        coordinator.setup()
        drainMainQueue()
        let handler = IrohaConnectURLHandler { url in
            coordinator.start(with: url)
        }
        let url = try XCTUnwrap(URL(string: "irohaconnect://connect?pairing=test"))

        XCTAssertTrue(handler.handle(url: url))
        drainMainQueue()

        XCTAssertEqual(notice.presentedCount, 1)
        XCTAssertEqual(sessionFactoryCalls, 0)
    }

    func testStart_whenPolicyDisabled_thenEvenMalformedLinksOnlyShowUnavailableNotice() throws {
        // The policy is checked before parsing: a malformed link would otherwise
        // produce the "not a canonical Taira request" error.
        let notice = UnavailableNoticeSpy()
        var sessionFactoryCalls = 0
        let coordinator = makeCoordinator(notice: notice) { _ in
            sessionFactoryCalls += 1
            throw SessionFactoryError.unexpectedCall
        }
        coordinator.setup()
        drainMainQueue()

        coordinator.start(with: try XCTUnwrap(URL(string: "iroha://connect")))

        XCTAssertEqual(notice.presentedCount, 1)
        XCTAssertEqual(sessionFactoryCalls, 0)
    }

    func testStart_whenLinkArrivesBeforeWalletIsUnlocked_thenNoticeWaitsForSetup() throws {
        let notice = UnavailableNoticeSpy()
        let coordinator = makeCoordinator(notice: notice)

        coordinator.start(with: try XCTUnwrap(URL(string: "irohaconnect://connect?pairing=test")))
        drainMainQueue()

        XCTAssertEqual(notice.presentAttempts, 0)

        coordinator.setup()
        drainMainQueue()

        XCTAssertEqual(notice.presentedCount, 1)
    }

    func testStart_whenWalletInterfaceIsThrottled_thenNoticeWaitsForNextSetup() throws {
        let notice = UnavailableNoticeSpy()
        let coordinator = makeCoordinator(notice: notice)
        coordinator.setup()
        coordinator.throttle()
        drainMainQueue()

        coordinator.start(with: try XCTUnwrap(URL(string: "irohaconnect://connect?pairing=test")))

        XCTAssertEqual(notice.presentAttempts, 0)

        coordinator.setup()
        drainMainQueue()

        XCTAssertEqual(notice.presentedCount, 1)
    }

    func testStart_whenNoticeIsShown_thenRepeatedLinksDoNotStackSheets() throws {
        let notice = UnavailableNoticeSpy()
        let coordinator = makeCoordinator(notice: notice)
        coordinator.setup()
        drainMainQueue()
        let url = try XCTUnwrap(URL(string: "irohaconnect://connect?pairing=test"))

        coordinator.start(with: url)
        coordinator.start(with: url)
        coordinator.start(with: url)

        XCTAssertEqual(notice.presentedCount, 1)

        notice.isPresentingNotice = false
        coordinator.start(with: url)

        XCTAssertEqual(notice.presentedCount, 2)
    }

    func testStart_whenPresentationIsRefused_thenNoticeIsRetriedOnceAppBecomesActive() throws {
        let notice = UnavailableNoticeSpy()
        notice.acceptsPresentation = false
        let notificationCenter = NotificationCenter()
        let coordinator = makeCoordinator(notice: notice, notificationCenter: notificationCenter)
        coordinator.setup()
        drainMainQueue()
        let url = try XCTUnwrap(URL(string: "irohaconnect://connect?pairing=test"))

        coordinator.start(with: url)
        coordinator.start(with: url)

        // The second link joins the pending notice instead of queueing another one.
        XCTAssertEqual(notice.presentAttempts, 1)
        XCTAssertEqual(notice.presentedCount, 0)

        notice.acceptsPresentation = true
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(notice.presentAttempts, 2)
        XCTAssertEqual(notice.presentedCount, 1)
    }

    func testPresentLanding_whenPolicyDisabled_thenPresentsUnavailableNoticeInsteadOfLanding() {
        let notice = UnavailableNoticeSpy()
        let coordinator = makeCoordinator(notice: notice)
        coordinator.setup()
        drainMainQueue()
        let presentingViewController = PresentationRecordingViewController()

        coordinator.presentLanding(from: presentingViewController)

        XCTAssertTrue(presentingViewController.presentedControllers.isEmpty)
        XCTAssertEqual(notice.presentedCount, 1)
    }

    func testQRCode_whenPolicyDisabled_thenPresentsUnavailableNoticeWithoutSession() {
        let notice = UnavailableNoticeSpy()
        var sessionFactoryCalls = 0
        let coordinator = makeCoordinator(notice: notice) { _ in
            sessionFactoryCalls += 1
            throw SessionFactoryError.unexpectedCall
        }
        coordinator.setup()
        drainMainQueue()

        coordinator.didFinishWith(rawCode: "irohaconnect://connect?pairing=test")

        XCTAssertEqual(notice.presentedCount, 1)
        XCTAssertEqual(sessionFactoryCalls, 0)
    }

    // MARK: - Account provider

    func testProviderSign_whenPolicyDisabled_thenThrowsBeforeLoadingMaterial() throws {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 5, count: 32))
        let descriptor = IrohaConnectAccountDescriptor(
            walletName: "Sakura",
            accountID: "iroha-account",
            publicKey: key.publicKey.rawRepresentation
        )
        var materialLoads = 0
        let materialLoader = { () throws -> (IrohaConnectAccountDescriptor, Data) in
            materialLoads += 1
            return (descriptor, key.rawRepresentation)
        }
        let providers = [
            KeychainIrohaConnectAccountProvider(materialLoader: materialLoader),
            KeychainIrohaConnectAccountProvider(policy: .production, materialLoader: materialLoader),
            KeychainIrohaConnectAccountProvider(
                policy: .production,
                descriptorLoader: { descriptor },
                materialLoader: materialLoader
            )
        ]

        for provider in providers {
            XCTAssertThrowsError(try provider.sign(Data("transfer payload hash".utf8), for: descriptor)) { error in
                XCTAssertEqual(error as? IrohaConnectAccountProviderError, .signingDisabled)
            }
        }

        XCTAssertEqual(materialLoads, 0)
        XCTAssertEqual(
            IrohaConnectAccountProviderError.signingDisabled.errorDescription,
            "IrohaConnect signing is disabled in this version."
        )
    }

    // MARK: - Unavailable notice

    func testUnavailableNotice_saysNothingWasSignedAndOffersOnlyClose() {
        let locale = Locale(identifier: "en")
        let viewModel = IrohaConnectUnavailableNoticePresenter.makeViewModel(locale: locale)

        XCTAssertEqual(viewModel.title, "IrohaConnect isn't available in this version")
        XCTAssertEqual(
            viewModel.message,
            "Fearless didn't connect to the app and nothing was signed. You can keep using your wallet as usual."
        )
        XCTAssertTrue(viewModel.actions.isEmpty)
        XCTAssertEqual(
            viewModel.closeAction,
            R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
        )
        // The info variant would hide the Close button.
        XCTAssertFalse(viewModel.isInfo)
        XCTAssertNil(viewModel.icon)
        // Without a dismiss completion the sheet also closes on a tap outside.
        XCTAssertNil(viewModel.dismissCompletion)
    }

    func testUnavailableNoticePresenter_whenAppIsInactiveOrNothingIsOnScreen_thenReportsNotPresented() {
        let inactive = IrohaConnectUnavailableNoticePresenter(
            topViewController: { UIViewController() },
            isApplicationActive: { false }
        )
        let empty = IrohaConnectUnavailableNoticePresenter(
            topViewController: { nil },
            isApplicationActive: { true }
        )

        XCTAssertFalse(inactive.presentUnavailableNotice())
        XCTAssertFalse(empty.presentUnavailableNotice())
        XCTAssertFalse(inactive.isPresentingNotice)
        XCTAssertFalse(empty.isPresentingNotice)
    }

    func testUnavailableNoticePresenter_whenClosed_thenTheNextNoticeCanBeShown() throws {
        let (window, root) = try hostInAppScene()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let presenter = IrohaConnectUnavailableNoticePresenter(
            topViewController: { root },
            isApplicationActive: { true }
        )

        XCTAssertTrue(presenter.presentUnavailableNotice())
        XCTAssertTrue(presenter.isPresentingNotice)
        let sheet = try XCTUnwrap(root.presentedViewController as? SheetAletViewController)
        waitUntil { !sheet.isBeingPresented }

        let buttons = sheet.view.irohaConnectTestDescendants(of: TriangularedButton.self)
        XCTAssertEqual(buttons.count, 1)
        XCTAssertEqual(
            buttons.first?.imageWithTitleView?.title,
            R.string.localizable.commonClose(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
            )
        )
        buttons.first?.sendActions(for: .touchUpInside)
        waitUntil { root.presentedViewController == nil }

        XCTAssertNil(root.presentedViewController)
        XCTAssertFalse(presenter.isPresentingNotice)
        XCTAssertTrue(presenter.presentUnavailableNotice())
        XCTAssertTrue(presenter.isPresentingNotice)
        root.dismiss(animated: false)
    }

    func testUnavailableNoticePresenter_whenUIKitRefusesPresentation_thenReportsNotPresented() throws {
        let (window, root) = try hostInAppScene()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let other = UIViewController()
        root.present(other, animated: false)
        waitUntil { root.presentedViewController === other && !other.isBeingPresented }
        // Deliberately not the top controller: UIKit refuses a second presentation.
        let presenter = IrohaConnectUnavailableNoticePresenter(
            topViewController: { root },
            isApplicationActive: { true }
        )

        XCTAssertFalse(presenter.presentUnavailableNotice())
        XCTAssertFalse(presenter.isPresentingNotice)
        XCTAssertTrue(root.presentedViewController === other)
        root.dismiss(animated: false)
    }

    // MARK: - Helpers

    private func makeCoordinator(
        notice: UnavailableNoticeSpy,
        notificationCenter: NotificationCenter = NotificationCenter(),
        sessionFactory: @escaping (IrohaConnectWalletURI) throws -> IrohaConnectSessionService = { _ in
            throw SessionFactoryError.unexpectedCall
        }
    ) -> IrohaConnectCoordinator {
        IrohaConnectCoordinator(
            policy: .production,
            sessionFactory: sessionFactory,
            unavailableNotice: notice,
            notificationCenter: notificationCenter
        )
    }

    private func makeProfileViewModelFactory(
        policy: IrohaConnectReleasePolicy? = nil
    ) -> ProfileViewModelFactory {
        let settings = InMemorySettingsManager()
        let fetcher = AccountStatisticsFetcherStub()
        if let policy {
            return ProfileViewModelFactory(
                iconGenerator: UniversalIconGenerator(),
                biometry: BiometryStub(),
                settings: settings,
                accountScoreFetcher: fetcher,
                irohaConnectPolicy: policy
            )
        }
        return ProfileViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            biometry: BiometryStub(),
            settings: settings,
            accountScoreFetcher: fetcher
        )
    }

    private func makeProfileOptions(factory: ProfileViewModelFactory) -> [ProfileOption] {
        let viewModel = factory.createProfileViewModel(
            from: AccountGenerator.generateMetaAccount(),
            locale: Locale(identifier: "en"),
            language: Language(code: "en"),
            currency: Currency.defaultCurrency(),
            balance: nil,
            missingAccountIssue: []
        )
        return viewModel.profileOptionViewModel.compactMap(\.option)
    }

    private func drainMainQueue() {
        let drained = expectation(description: "Main queue drained")
        DispatchQueue.main.async {
            drained.fulfill()
        }
        wait(for: [drained], timeout: 1)
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
    }

    private func hostInAppScene() throws -> (UIWindow, UIViewController) {
        // Presentations only complete in a window of the host app's scene.
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let root = UIViewController()
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = root
        window.makeKeyAndVisible()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        return (window, root)
    }
}

private final class UnavailableNoticeSpy: IrohaConnectUnavailableNoticePresenting {
    var isPresentingNotice = false
    var acceptsPresentation = true
    private(set) var presentAttempts = 0
    private(set) var presentedCount = 0

    func presentUnavailableNotice() -> Bool {
        presentAttempts += 1
        guard acceptsPresentation else {
            return false
        }

        presentedCount += 1
        isPresentingNotice = true
        return true
    }
}

private final class PresentationRecordingViewController: UIViewController {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated _: Bool,
        completion _: (() -> Void)? = nil
    ) {
        presentedControllers.append(viewControllerToPresent)
    }
}

private struct BiometryStub: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }

    func authenticate(
        localizedReason _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        completionQueue.async {
            completionBlock(false)
        }
    }
}

private struct AccountStatisticsFetcherStub: AccountStatisticsFetching {
    func subscribeForStatistics(
        address _: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}

private extension UIView {
    func irohaConnectTestDescendants<T: UIView>(of type: T.Type) -> [T] {
        subviews.flatMap { subview -> [T] in
            let match = (subview as? T).map { [$0] } ?? []
            return match + subview.irohaConnectTestDescendants(of: type)
        }
    }
}
