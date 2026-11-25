import XCTest
import UIKit
@testable import fearless

#if DEBUG

    /// Records unavailable-notice requests instead of presenting a sheet.
    final class CovJMxIrohaNoticeSpy: IrohaConnectUnavailableNoticePresenting {
        var isPresentingNotice = false
        private(set) var attempts = 0

        func presentUnavailableNotice() -> Bool {
            attempts += 1
            return true
        }
    }

    final class CovJMxPasteboard: PasteboardStringAccessing {
        var string: String?
    }

    /// Never signs and has no account: nothing in these tests may reach signing material.
    final class CovJMxIrohaAccountProvider: IrohaConnectAccountProviding {
        func selectedAccount() throws -> IrohaConnectAccountDescriptor {
            throw IrohaConnectAccountProviderError.accountUnavailable
        }

        func sign(_: Data, for _: IrohaConnectAccountDescriptor) throws -> Data {
            throw IrohaConnectAccountProviderError.signingDisabled
        }
    }

    /// Builds real session services that are closed before the coordinator starts them, so no socket is ever opened.
    final class CovJMxIrohaSessionBox {
        var failure: Error?
        private(set) var handoffs: [IrohaConnectWalletURI] = []
        private(set) var services: [IrohaConnectSessionService] = []

        func make(_ handoff: IrohaConnectWalletURI) throws -> IrohaConnectSessionService {
            handoffs.append(handoff)
            if let failure { throw failure }
            let service = IrohaConnectSessionService(
                handoff: handoff,
                accountProvider: CovJMxIrohaAccountProvider(),
                transport: IrohaConnectFakeTransport()
            )
            // `close()` and `start()` run on the same serial queue: the session is finished before it can connect.
            service.close()
            services.append(service)
            return service
        }
    }

    final class CovJMxIrohaConnectCoordinatorTests: XCTestCase {
        /// A current Taira wallet invitation (from the web wallet's vectors).
        private static var walletURI: String {
            IrohaConnectWebVectors.string("link", "irohaconnectUri")
        }

        private static let invalidLinkMessage = "This IrohaConnect link is invalid. Create a new connection in the app."

        private let account = IrohaConnectAccountDescriptor(
            walletName: "Sakura",
            accountID: "sora0123456789abcdefghijklmnopqrstuvwxyz",
            publicKey: Data(repeating: 1, count: 32)
        )

        private var notice = CovJMxIrohaNoticeSpy()
        private var box = CovJMxIrohaSessionBox()
        private var center = NotificationCenter()
        private var pasteboard = CovJMxPasteboard()

        override func setUp() {
            super.setUp()
            notice = CovJMxIrohaNoticeSpy()
            box = CovJMxIrohaSessionBox()
            center = NotificationCenter()
            pasteboard = CovJMxPasteboard()
        }

        override func tearDown() {
            hideIrohaWindows()
            super.tearDown()
        }

        // MARK: - Links and QR codes

        func testValidLinkStartsASessionAndRestartReplacesThePreviousOne() throws {
            let coordinator = makeCoordinator()
            let url = try XCTUnwrap(URL(string: Self.walletURI))

            coordinator.start(with: url)
            let first = try XCTUnwrap(box.services.first)
            XCTAssertTrue(first.delegate === coordinator)
            XCTAssertEqual(box.handoffs.first?.webSocketSubprotocol.hasPrefix("iroha-connect.token.v1."), true)

            coordinator.start(with: url)
            XCTAssertEqual(box.services.count, 2)
            XCTAssertNil(first.delegate)
            let second = try XCTUnwrap(box.services.last)
            XCTAssertTrue(second.delegate === coordinator)
            second.delegate = nil
            XCTAssertEqual(notice.attempts, 0)
        }

        func testRawCodeAcceptanceOnlyAllowsCanonicalPairingLinks() {
            let coordinator = makeCoordinator()

            XCTAssertTrue(coordinator.shouldAccept(rawCode: Self.walletURI))
            XCTAssertFalse(coordinator.shouldAccept(rawCode: ""))
            XCTAssertFalse(coordinator.shouldAccept(rawCode: "https://example.invalid/connect"))
            XCTAssertFalse(coordinator.shouldAccept(rawCode: "irohaconnect://connect?sid=x"))
        }

        func testScannedPairingLinkStartsASession() throws {
            let coordinator = makeCoordinator()

            coordinator.didFinishWith(rawCode: Self.walletURI)

            let service = try XCTUnwrap(box.services.first)
            XCTAssertTrue(service.delegate === coordinator)
            service.delegate = nil
            XCTAssertEqual(box.handoffs.count, 1)
        }

        func testMalformedLinkShowsCanonicalLinkErrorWithoutCreatingASession() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let coordinator = makeCoordinator()

            coordinator.start(with: try XCTUnwrap(URL(string: "irohaconnect://connect?sid=x")))

            let alert = try XCTUnwrap(presentedAlert(on: root))
            XCTAssertEqual(alert.title, "IrohaConnect")
            XCTAssertEqual(alert.message, Self.invalidLinkMessage)
            XCTAssertEqual(alert.actions.map(\.title), ["OK"])
            XCTAssertTrue(box.handoffs.isEmpty)
        }

        func testSessionFactoryFailureShowsCanonicalLinkError() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            box.failure = CovJError("relay unavailable")
            let coordinator = makeCoordinator()

            coordinator.start(with: try XCTUnwrap(URL(string: Self.walletURI)))

            XCTAssertEqual(box.handoffs.count, 1)
            XCTAssertTrue(box.services.isEmpty)
            let alert = try XCTUnwrap(presentedAlert(on: root))
            XCTAssertEqual(alert.message, Self.invalidLinkMessage)
        }

        func testEmptyScannedCodeShowsInvalidRequestError() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let coordinator = makeCoordinator()

            coordinator.didFinishWith(rawCode: "")

            let alert = try XCTUnwrap(presentedAlert(on: root))
            XCTAssertEqual(alert.message, Self.invalidLinkMessage)
            XCTAssertTrue(box.handoffs.isEmpty)
        }

        func testURLHandlerAcceptsOnlyConnectLinksOfBothSchemes() throws {
            var started: [String] = []
            let handler = IrohaConnectURLHandler { started.append($0.absoluteString) }

            XCTAssertFalse(handler.handle(url: try XCTUnwrap(URL(string: "https://connect.example.invalid"))))
            XCTAssertFalse(handler.handle(url: try XCTUnwrap(URL(string: "iroha://pair?x=1"))))
            XCTAssertFalse(handler.handle(url: try XCTUnwrap(URL(string: "fearless://connect"))))
            XCTAssertTrue(handler.handle(url: try XCTUnwrap(URL(string: "IROHA://CONNECT?x=1"))))
            XCTAssertTrue(handler.handle(url: try XCTUnwrap(URL(string: "irohaconnect://connect"))))
            XCTAssertTrue(started.isEmpty)

            XCTAssertTrue(CovJWait.until { started.count == 2 })
            XCTAssertEqual(started.map { $0.lowercased() }, ["iroha://connect?x=1", "irohaconnect://connect"])
        }

        // MARK: - Landing

        func testLandingIsPresentedFullScreenAndClosesItself() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let coordinator = makeCoordinator()

            coordinator.presentLanding(from: nil)
            XCTAssertNil(root.presentedViewController)

            coordinator.presentLanding(from: root)

            let navigation = try XCTUnwrap(root.presentedViewController as? FearlessNavigationController)
            XCTAssertEqual(navigation.modalPresentationStyle, .fullScreen)
            let landing = try XCTUnwrap(navigation.viewControllers.first as? IrohaConnectLandingViewController)
            XCTAssertNotNil(landing.onScan)
            XCTAssertNotNil(landing.onPaste)
            XCTAssertTrue(CovJWait.until(timeout: 3) { !navigation.isBeingPresented })

            landing.onClose?()

            XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController == nil })
            XCTAssertEqual(notice.attempts, 0)
        }

        func testPastedLinkStartsASessionAndAnInvalidOneExplainsWhy() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let coordinator = makeCoordinator()
            coordinator.presentLanding(from: root)
            let navigation = try XCTUnwrap(root.presentedViewController as? FearlessNavigationController)
            let landing = try XCTUnwrap(navigation.viewControllers.first as? IrohaConnectLandingViewController)
            XCTAssertTrue(CovJWait.until(timeout: 3) { !navigation.isBeingPresented })

            pasteboard.string = "  \(Self.walletURI)\n"
            landing.onPaste?()
            XCTAssertEqual(box.handoffs.count, 1)
            box.services.last?.delegate = nil

            pasteboard.string = IrohaConnectWebVectors.string("link", "uri").replacingOccurrences(of: "v=1", with: "v=2")
            landing.onPaste?()
            XCTAssertEqual(box.handoffs.count, 1)
            XCTAssertTrue(CovJWait.until(timeout: 3) {
                (landing.presentedViewController as? UIAlertController)?.message == Self.invalidLinkMessage
            })
        }

        // MARK: - Approval prompts

        func testRequestArrivingWhileThePromptFadesOutIsShownAfterwards() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()
            let open = IrohaConnectOpenFrame(
                appPublicKey: Data(repeating: 2, count: 32),
                appMetadata: nil,
                networkID: Data(repeating: 3, count: 32),
                permissions: nil,
                permissionsField: Data([0])
            )
            coordinator.irohaConnectSession(service, requestsConnection: open, account: account)
            let cover = try XCTUnwrap(promptWindow())

            coordinator.irohaConnectSessionDidApprove(service)
            coordinator.irohaConnectSession(service, requestsSignature: signatureRequest())

            XCTAssertTrue(CovJWait.until(timeout: 3) { cover.isHidden })
            XCTAssertTrue(CovJWait.until(timeout: 3) {
                (promptWindow()?.rootViewController as? IrohaConnectPromptViewController).map { labels(in: $0).contains("Approve transfer") } ?? false
            })
        }

        func testConnectionRequestCoversTheAppAndRejectClosesTheSession() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()
            let open = IrohaConnectOpenFrame(
                appPublicKey: Data(repeating: 2, count: 32),
                appMetadata: IrohaConnectAppMetadata(name: "Uranai", url: "https://uranai.invalid/app", iconHash: nil),
                networkID: Data(repeating: 3, count: 32),
                permissions: nil,
                permissionsField: Data([0])
            )

            coordinator.irohaConnectSession(service, requestsConnection: open, account: account)

            let cover = try XCTUnwrap(promptWindow())
            XCTAssertEqual(cover.windowLevel, UIWindow.Level.alert + 1)
            XCTAssertEqual(cover.alpha, 1)
            let prompt = try XCTUnwrap(cover.rootViewController as? IrohaConnectPromptViewController)
            let texts = labels(in: prompt)
            XCTAssertTrue(texts.contains("Connect your SORA wallet"))
            XCTAssertTrue(texts.contains("Uranai"))
            XCTAssertTrue(texts.contains("uranai.invalid"))
            XCTAssertTrue(texts.contains("Taira Testnet"))
            XCTAssertTrue(texts.contains(IrohaConnectPrompt.shortenedAccountID(account.accountID)))

            prompt.onReject?()

            XCTAssertTrue(CovJWait.until(timeout: 3) { cover.isHidden })
            XCTAssertNil(cover.rootViewController)
            XCTAssertTrue(window.isKeyWindow)
            // The rejected session is forgotten: later callbacks from it are ignored.
            coordinator.irohaConnectSession(service, requestsConnection: open, account: account)
            XCTAssertNil(promptWindow())
        }

        func testSignatureRequestShowsTheDecodedTransferAndCompletionDismissesIt() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()
            let request = signatureRequest()

            coordinator.irohaConnectSession(service, requestsSignature: request)

            let cover = try XCTUnwrap(promptWindow())
            let prompt = try XCTUnwrap(cover.rootViewController as? IrohaConnectPromptViewController)
            let texts = labels(in: prompt)
            XCTAssertTrue(texts.contains("Approve transfer"))
            XCTAssertTrue(texts.contains("Iroha dApp"))
            XCTAssertTrue(texts.contains("0.001 XOR"))
            XCTAssertTrue(texts.contains(try XCTUnwrap(request.review.transfer?.destination)))
            XCTAssertFalse(texts.contains("CLAIMED ORIGIN"))

            // Callbacks from a session that is not the current one are ignored.
            let stranger = try box.make(XCTUnwrap(box.handoffs.first))
            coordinator.irohaConnectSessionDidCompleteSignature(stranger)
            coordinator.irohaConnectSessionDidApprove(stranger)
            CovJWait.drain(0.3)
            XCTAssertFalse(cover.isHidden)

            coordinator.irohaConnectSessionDidCompleteSignature(service)

            XCTAssertTrue(CovJWait.until(timeout: 3) { cover.isHidden })
            XCTAssertNil(promptWindow())
        }

        func testApprovedConnectionWithoutMetadataDismissesThePrompt() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()
            let open = IrohaConnectOpenFrame(
                appPublicKey: Data(repeating: 2, count: 32),
                appMetadata: nil,
                networkID: Data(repeating: 3, count: 32),
                permissions: nil,
                permissionsField: Data([0])
            )

            coordinator.irohaConnectSession(service, requestsConnection: open, account: account)

            let cover = try XCTUnwrap(promptWindow())
            let texts = try labels(in: XCTUnwrap(cover.rootViewController))
            XCTAssertTrue(texts.contains("Iroha dApp"))
            XCTAssertFalse(texts.contains("CLAIMED ORIGIN"))

            coordinator.irohaConnectSessionDidApprove(service)

            XCTAssertTrue(CovJWait.until(timeout: 3) { cover.isHidden })
            XCTAssertTrue(window.isKeyWindow)
        }

        func testClosedSessionDismissesThePromptThenExplainsTheError() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()
            coordinator.irohaConnectSession(service, requestsSignature: signatureRequest())
            let cover = try XCTUnwrap(promptWindow())

            coordinator.irohaConnectSession(service, didCloseWith: IrohaConnectSessionServiceError.transportUnavailable)

            XCTAssertTrue(CovJWait.until(timeout: 3) { cover.isHidden })
            let alert = try XCTUnwrap(presentedAlert(on: root))
            XCTAssertEqual(alert.message, IrohaConnectSessionServiceError.transportUnavailable.errorDescription)
            // The session is gone: another close report changes nothing.
            root.dismiss(animated: false)
            coordinator.irohaConnectSession(service, didCloseWith: CovJError())
            CovJWait.drain(0.3)
            XCTAssertNil(root.presentedViewController)
        }

        func testDecliningATransactionKeepsTheSession() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()
            coordinator.irohaConnectSession(service, requestsSignature: signatureRequest())
            let cover = try XCTUnwrap(promptWindow())
            let prompt = try XCTUnwrap(cover.rootViewController as? IrohaConnectPromptViewController)

            prompt.onReject?()

            XCTAssertTrue(CovJWait.until(timeout: 3) { cover.isHidden })
            // The session is still current: its next request is shown again.
            coordinator.irohaConnectSession(service, requestsSignature: signatureRequest())
            XCTAssertTrue(CovJWait.until(timeout: 3) { promptWindow() != nil })
        }

        func testRefusedRequestsExplainThatNothingWasSigned() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()

            coordinator.irohaConnectSession(service, didRefuse: .rawSigningUnavailable)

            let alert = try XCTUnwrap(presentedAlert(on: root))
            XCTAssertEqual(alert.message, IrohaConnectCoordinator.message(for: .rawSigningUnavailable))
            let notices: [IrohaConnectNotice] = [
                .rawSigningUnavailable, .requestInProgress, .permissionDenied, .transactionInvalid,
                .transactionUnsupported, .transactionWrongAccount, .requestExpired
            ]
            let messages = notices.map(IrohaConnectCoordinator.message(for:))
            XCTAssertEqual(Set(messages).count, notices.count)
            XCTAssertTrue(messages.allSatisfy { $0.contains("sign") || $0.contains("declined") })
        }

        func testClaimedOriginIsShownOnlyForHTTPSOrLoopback() {
            XCTAssertEqual(IrohaConnectCoordinator.normalizedAppURL("https://app.example/x")?.host, "app.example")
            XCTAssertEqual(IrohaConnectCoordinator.normalizedAppURL("http://localhost:3000")?.host, "localhost")
            XCTAssertNil(IrohaConnectCoordinator.normalizedAppURL("http://app.example"))
            XCTAssertNil(IrohaConnectCoordinator.normalizedAppURL("https://user:pass@app.example"))
            XCTAssertNil(IrohaConnectCoordinator.normalizedAppURL("javascript:alert(1)"))
            XCTAssertNil(IrohaConnectCoordinator.normalizedAppURL(nil))
        }

        func testCleanCloseWithoutPromptShowsNoError() throws {
            let (window, root) = try hostRoot()
            defer { close(window, root) }
            let (coordinator, service) = try startedSession()

            coordinator.irohaConnectSession(service, didCloseWith: nil)
            center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

            CovJWait.drain(0.3)
            XCTAssertNil(root.presentedViewController)
            XCTAssertNil(promptWindow())
            XCTAssertEqual(notice.attempts, 0)
        }

    }

    // MARK: - Helpers

    extension CovJMxIrohaConnectCoordinatorTests {
        private func makeCoordinator() -> IrohaConnectCoordinator {
            let box = box
            return IrohaConnectCoordinator(
                policy: .enabledForTests,
                sessionFactory: { try box.make($0) },
                unavailableNotice: notice,
                notificationCenter: center,
                pasteboard: pasteboard
            )
        }

        private func signatureRequest() -> IrohaConnectPendingSignature {
            let reviewed = IrohaConnectWebVectors.reviewedTransaction("transfer xor")
            return IrohaConnectPendingSignature(
                requestID: UUID().uuidString,
                account: account,
                review: reviewed.review,
                payloadHash: reviewed.payloadHash
            )
        }

        /// Starts a session whose own close report is suppressed, so the test drives the delegate callbacks.
        private func startedSession() throws -> (IrohaConnectCoordinator, IrohaConnectSessionService) {
            let coordinator = makeCoordinator()
            coordinator.start(with: try XCTUnwrap(URL(string: Self.walletURI)))
            let service = try XCTUnwrap(box.services.last)
            XCTAssertTrue(service.delegate === coordinator)
            service.delegate = nil
            XCTAssertTrue(CovJWait.until(timeout: 5) { UIApplication.shared.applicationState == .active })
            return (coordinator, service)
        }

        private func hostRoot() throws -> (UIWindow, UIViewController) {
            let root = UIViewController()
            let window = try CovJViewFixture.host(root)
            return (window, root)
        }

        private func close(_ window: UIWindow, _ root: UIViewController) {
            root.presentedViewController?.dismiss(animated: false)
            hideIrohaWindows()
            window.isHidden = true
        }

        private func presentedAlert(on root: UIViewController) -> UIAlertController? {
            CovJWait.until(timeout: 3) {
                guard let alert = root.presentedViewController as? UIAlertController else { return false }
                return !alert.isBeingPresented
            }
            return root.presentedViewController as? UIAlertController
        }

        private func allWindows() -> [UIWindow] {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        }

        private func promptWindow() -> UIWindow? {
            allWindows().first { !$0.isHidden && $0.rootViewController is IrohaConnectPromptViewController }
        }

        private func hideIrohaWindows() {
            for window in allWindows() where window.rootViewController is IrohaConnectPromptViewController {
                window.isHidden = true
                window.rootViewController = nil
            }
        }

        private func labels(in controller: UIViewController) -> [String] {
            CovJViewFixture.descendants(UILabel.self, in: controller.view).compactMap(\.text)
        }
    }

#endif
