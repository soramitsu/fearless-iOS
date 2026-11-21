import FearlessWalletConnect
import Foundation
import SoraKeystore
import UIKit
import XCTest
@testable import fearless

/// Nothing is signed without the PIN or biometrics, and WalletConnect requests never
/// appear above the PIN screen that locks the app after inactivity.
final class WalletConnectAuthorizationAndLockTests: XCTestCase {
    // MARK: - Authorization before signing

    func testApprove_whenTheUserDoesNotConfirm_thenNothingIsSignedOrSent() async throws {
        let signer = SignerSpy()
        let service = WalletConnectServiceSpy()
        let (interactor, _) = try makeInteractor(signer: signer, service: service, authorizer: AuthorizerStub(result: false))

        do {
            _ = try await interactor.approve()
            XCTFail("Signing must wait for the PIN or biometrics")
        } catch WalletConnectSigningError.notAuthorized {}

        XCTAssertTrue(signer.requests.isEmpty)
        XCTAssertTrue(service.signDecisions.isEmpty)
    }

    func testApprove_afterConfirmation_thenSignsTheShownRequestOnceAndSendsIt() async throws {
        let signer = SignerSpy()
        let service = WalletConnectServiceSpy()
        let authorizer = AuthorizerStub(result: true)
        let (interactor, signingRequest) = try makeInteractor(signer: signer, service: service, authorizer: authorizer)

        _ = try await interactor.approve()

        XCTAssertEqual(authorizer.calls, 1)
        XCTAssertEqual(signer.requests.map(\.request.id), [signingRequest.request.id])
        guard case let .signed(request, signature) = service.signDecisions.first else {
            return XCTFail("The signature must be sent")
        }
        XCTAssertEqual(request.id, signingRequest.request.id)
        XCTAssertEqual(try signature.get(String.self), "0x5167")
    }

    func testApprove_whenTheDAppStoppedWaitingBeforeThePin_thenNoPinIsAskedAndNothingIsSigned() async throws {
        let signer = SignerSpy()
        let service = WalletConnectServiceSpy()
        service.pendingAnswers = [false]
        let authorizer = AuthorizerStub(result: true)
        let (interactor, _) = try makeInteractor(signer: signer, service: service, authorizer: authorizer)

        do {
            _ = try await interactor.approve()
            XCTFail("A request nobody waits for must not be signed")
        } catch WalletConnectSigningError.requestEnded {}

        XCTAssertEqual(authorizer.calls, 0)
        XCTAssertTrue(signer.requests.isEmpty)
        XCTAssertTrue(service.signDecisions.isEmpty)
    }

    func testApprove_whenTheDAppStopsWaitingWhileThePinIsAsked_thenNothingIsSigned() async throws {
        let signer = SignerSpy()
        let service = WalletConnectServiceSpy()
        service.pendingAnswers = [true, false]
        let authorizer = AuthorizerStub(result: true)
        let (interactor, _) = try makeInteractor(signer: signer, service: service, authorizer: authorizer)

        do {
            _ = try await interactor.approve()
            XCTFail("A request that ended during the PIN must not be signed")
        } catch WalletConnectSigningError.requestEnded {}

        XCTAssertEqual(authorizer.calls, 1)
        XCTAssertEqual(service.pendingChecks, 2)
        XCTAssertTrue(signer.requests.isEmpty)
        XCTAssertTrue(service.signDecisions.isEmpty)
    }

    func testApprove_whenTheRequestEndsAsTheSignatureIsSent_thenItIsReportedAsEnded() async throws {
        let signer = SignerSpy()
        let service = WalletConnectServiceSpy()
        service.signedSubmitError = WalletConnectClient.ClientError.requestNotFound
        let (interactor, _) = try makeInteractor(signer: signer, service: service, authorizer: AuthorizerStub(result: true))

        do {
            _ = try await interactor.approve()
            XCTFail("A signature the dApp never got must not be reported as given")
        } catch WalletConnectSigningError.requestEnded {}
    }

    @MainActor
    func testAuthorizer_whenNoPinIsSet_thenDeclinesWithoutAPrompt() async throws {
        let (window, root) = try hostInAppScene()
        defer { window.isHidden = true }
        let authorizer = WalletConnectSigningAuthorizer(keystore: InMemoryKeychain())
        authorizer.view = root

        let authorized = await authorizer.authorize()

        XCTAssertFalse(authorized)
        XCTAssertNil(root.presentedViewController)
    }

    @MainActor
    func testAuthorizer_presentsThePinScreenAndReportsItsResult() async throws {
        let outcome = try await authorizeWithPinScreen(answering: true)

        XCTAssertEqual(outcome, true)
    }

    @MainActor
    func testAuthorizer_whenTheUserClosesThePinScreen_thenNothingIsAuthorized() async throws {
        let outcome = try await authorizeWithPinScreen(answering: false)

        XCTAssertEqual(outcome, false)
    }

    @MainActor
    private func authorizeWithPinScreen(answering answer: Bool) async throws -> Bool? {
        let (window, root) = try hostInAppScene()
        defer { window.isHidden = true }
        let keystore = InMemoryKeychain()
        try keystore.addKey(Data("123456".utf8), with: fearless.KeystoreTag.pincode.rawValue)
        let authorizer = WalletConnectSigningAuthorizer(keystore: keystore)
        authorizer.view = root

        let finished = expectation(description: "authorization finished")
        var outcome: Bool?
        Task {
            outcome = await authorizer.authorize()
            finished.fulfill()
        }
        // The PIN screen reports its result once the user is done with it, after it is fully shown.
        await waitUntil {
            guard let pinScreen = root.presentedViewController else {
                return false
            }
            return pinScreen is PinSetupViewProtocol && !pinScreen.isBeingPresented
        }
        XCTAssertTrue(authorizer.isAuthorizing)
        let pinScreen = try XCTUnwrap(root.presentedViewController as? PinSetupViewController)
        let pinPresenter = try XCTUnwrap(pinScreen.presenter as? ScreenAuthorizationPresenter)

        // As the PIN screen reports a correct PIN, or the user closing it.
        if answer {
            pinPresenter.didCompleteAuth()
        } else {
            pinPresenter.cancel()
        }

        await fulfillment(of: [finished], timeout: 5)
        return outcome
    }

    // MARK: - The inactivity lock

    func testCoordinator_whenTheAppIsLocked_thenRequestsWaitUntilItIsUnlocked() throws {
        let fixture = CoordinatorFixture()
        fixture.lockState.lock(with: fixture.lockScreen)

        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil, verification: .verified)

        XCTAssertEqual(fixture.flows.count, 1)
        XCTAssertEqual(fixture.flows.first?.starts, 0, "Nothing may appear above the PIN screen")

        fixture.lockState.unlock()

        XCTAssertEqual(fixture.flows.first?.starts, 1)
    }

    func testCoordinator_whenTheSameRequestArrivesAgain_thenItIsShownOnce() throws {
        let fixture = CoordinatorFixture()
        let request = try Self.makeRequest()

        fixture.coordinator.sign(request: request, session: nil, verification: .verified)
        fixture.coordinator.sign(request: request, session: nil, verification: .verified)

        XCTAssertEqual(fixture.flows.count, 1)

        fixture.flows.first?.finishFlow?()
        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil, verification: .verified)

        XCTAssertEqual(fixture.flows.count, 2)
        XCTAssertEqual(fixture.flows.last?.starts, 1)
    }

    func testCoordinator_whenARequestIsOnScreen_thenTheNextOneWaits() throws {
        let fixture = CoordinatorFixture()

        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil, verification: .verified)
        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil, verification: .verified)

        XCTAssertEqual(fixture.flows.map(\.starts), [1, 0])

        fixture.flows.first?.finishFlow?()

        XCTAssertEqual(fixture.flows.map(\.starts), [1, 1])
    }

    // MARK: - Requests the dApp stopped waiting for

    func testCoordinator_whenAQueuedRequestEnds_thenItLeavesTheQueueUnseen() throws {
        let fixture = CoordinatorFixture()
        let shown = try Self.makeRequest()
        let queued = try Self.makeRequest()
        fixture.coordinator.sign(request: shown, session: nil, verification: .verified)
        fixture.coordinator.sign(request: queued, session: nil, verification: .verified)

        fixture.coordinator.requestEnded(id: queued.id, topic: queued.topic)
        XCTAssertEqual(fixture.flows.map(\.starts), [1, 0])
        XCTAssertEqual(fixture.router.dismissals, 0, "The request on screen stays")
        XCTAssertFalse(fixture.requestEndedNotice.isNoticePending)

        fixture.flows[0].finishFlow?()
        XCTAssertEqual(fixture.flows.map(\.starts), [1, 0], "The ended request is never shown")
        XCTAssertTrue(fixture.coordinator.childCoordinators.isEmpty)
    }

    func testCoordinator_whenTheRequestOnScreenEnds_thenItClosesSaysSoAndTheNextOneShows() throws {
        let fixture = CoordinatorFixture()
        let shown = try Self.makeRequest()
        fixture.coordinator.sign(request: shown, session: nil, verification: .verified)
        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil, verification: .verified)

        fixture.coordinator.requestEnded(id: shown.id, topic: shown.topic)

        XCTAssertEqual(fixture.router.dismissals, 1)
        XCTAssertEqual(fixture.flows.map(\.starts), [1, 1])
        XCTAssertTrue(fixture.requestEndedNotice.isNoticePending)
    }

    func testCoordinator_whenTheRequestOnScreenIsSigning_thenItStaysOpen() throws {
        let fixture = CoordinatorFixture()
        let shown = try Self.makeRequest()
        fixture.coordinator.sign(request: shown, session: nil, verification: .verified)
        fixture.flows[0].isSigning = true

        fixture.coordinator.requestEnded(id: shown.id, topic: shown.topic)

        // The PIN screen may be up: the signing's own checks stop it instead.
        XCTAssertEqual(fixture.router.dismissals, 0)
        XCTAssertFalse(fixture.requestEndedNotice.isNoticePending)
    }

    func testCoordinator_whenASessionEnds_thenEveryRequestOfItEnds() throws {
        let fixture = CoordinatorFixture()
        let blockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let first = Request(topic: "session-a", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)
        let second = Request(topic: "session-a", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)
        let other = Request(topic: "session-b", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)
        [first, second, other].forEach { fixture.coordinator.sign(request: $0, session: nil, verification: .verified) }

        fixture.coordinator.sessionEnded(topic: "session-a")

        XCTAssertEqual(fixture.router.dismissals, 1)
        XCTAssertEqual(fixture.flows.map(\.starts), [1, 0, 1], "Only the other session's request is shown next")
        XCTAssertEqual(fixture.coordinator.childCoordinators.count, 1)
    }

    func testCoordinator_whenAProposalExpires_thenItLeavesTheQueue() throws {
        let fixture = CoordinatorFixture()
        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil, verification: .verified)
        let proposal = try WalletConnectVerifyTests.makeProposal()
        fixture.coordinator.session(proposal: proposal, verification: .verified)

        fixture.coordinator.proposalEnded(id: proposal.id)
        fixture.flows[0].finishFlow?()

        XCTAssertEqual(fixture.flows.map(\.starts), [1, 0])
        XCTAssertTrue(fixture.coordinator.childCoordinators.isEmpty)
    }

    func testCoordinator_requestsWithTheSameIdInTwoSessionsAreBothShown() throws {
        let fixture = CoordinatorFixture()
        let blockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let first = Request(id: 7, topic: "session-a", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)
        let second = Request(id: 7, topic: "session-b", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)

        fixture.coordinator.sign(request: first, session: nil, verification: .verified)
        fixture.coordinator.sign(request: second, session: nil, verification: .verified)
        fixture.coordinator.sign(request: first, session: nil, verification: .verified)

        XCTAssertEqual(fixture.flows.count, 2)
    }

    func testCoordinator_whenOneSessionSendsTooManyRequests_thenOnlyItsExtraOnesAreDeclined() throws {
        let fixture = CoordinatorFixture()
        let blockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let flood = (0 ..< WalletConnectCoordinator.maxRequestsPerSession + 2).map { _ in
            Request(topic: "busy-session", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)
        }
        let other = Request(topic: "other-session", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)

        flood.forEach { fixture.coordinator.sign(request: $0, session: nil, verification: .verified) }
        fixture.coordinator.sign(request: other, session: nil, verification: .verified)
        let proposal = try WalletConnectVerifyTests.makeProposal()
        fixture.coordinator.session(proposal: proposal, verification: .verified)

        // The busy session gets its share; the other session and the proposal still wait their turn.
        XCTAssertEqual(fixture.flows.count, WalletConnectCoordinator.maxRequestsPerSession + 2)
        try spin { fixture.service.signDecisions.count == 2 }
        XCTAssertEqual(
            Set(fixture.service.signDecisions.compactMap(Self.declinedRequestId)),
            Set(flood.suffix(2).map(\.id))
        )
        XCTAssertTrue(fixture.service.proposalDecisions.isEmpty)
    }

    func testCoordinator_whenProposalsPileUp_thenTheExtraOnesAreDeclinedAndRequestsStillWait() throws {
        let fixture = CoordinatorFixture()
        let proposals = try (0 ..< WalletConnectCoordinator.maxQueuedProposals + 1).map { index in
            Session.Proposal(
                id: Int64(1_794_000_000_000_100 + index),
                pairingTopic: "pairing-\(index)",
                proposer: try WalletConnectVerifyTests.makeProposal().proposer,
                requiredNamespaces: [:],
                optionalNamespaces: nil,
                sessionProperties: nil,
                expiryDate: Date(timeIntervalSinceNow: 300)
            )
        }

        proposals.forEach { fixture.coordinator.session(proposal: $0, verification: .verified) }
        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil, verification: .verified)

        XCTAssertEqual(fixture.flows.count, WalletConnectCoordinator.maxQueuedProposals + 1)
        try spin { fixture.service.proposalDecisions.count == 1 }
        guard case let .reject(rejected) = fixture.service.proposalDecisions.first else {
            return XCTFail("The extra proposal must be declined")
        }
        XCTAssertEqual(rejected.id, proposals.last?.id)
        XCTAssertTrue(fixture.service.signDecisions.isEmpty, "The request still waits")
    }

    func testCoordinator_whenEveryShareIsTaken_thenTheCeilingHolds() throws {
        let fixture = CoordinatorFixture()
        let blockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let sessions = WalletConnectCoordinator.maxQueuedFlows / WalletConnectCoordinator.maxRequestsPerSession
        for session in 0 ..< sessions {
            for _ in 0 ..< WalletConnectCoordinator.maxRequestsPerSession {
                fixture.coordinator.sign(
                    request: Request(topic: "session-\(session)", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain),
                    session: nil,
                    verification: .verified
                )
            }
        }
        let late = Request(topic: "late-session", method: "personal_sign", params: AnyCodable(["0x00"]), chainId: blockchain)

        fixture.coordinator.sign(request: late, session: nil, verification: .verified)

        XCTAssertEqual(fixture.flows.count, WalletConnectCoordinator.maxQueuedFlows)
        try spin { fixture.service.signDecisions.count == 1 }
        XCTAssertEqual(fixture.service.signDecisions.compactMap(Self.declinedRequestId), [late.id])
    }

    private static func declinedRequestId(_ decision: WalletConnectSignDecision) -> Int64? {
        guard case let .rejected(request, error) = decision, error == .userRejected else {
            return nil
        }
        return request.id
    }

    func testRouter_whenTheAppLocks_thenHidesTheRequestWindowUntilItIsUnlocked() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let notificationCenter = NotificationCenter()
        let lockState = ApplicationLockState(notificationCenter: notificationCenter)
        let router = WalletConnectCoordinatorRouterImpl(
            lockState: lockState,
            notificationCenter: notificationCenter,
            windowScene: { scene }
        )

        router.setRoot(controller: UIViewController())
        let window = try XCTUnwrap(router.coveringWindow)
        XCTAssertFalse(window.isHidden)

        let lockScreen = UIViewController()
        lockState.lock(with: lockScreen)
        XCTAssertTrue(window.isHidden, "The request window must not cover the PIN screen")

        lockState.unlock()
        XCTAssertFalse(window.isHidden)
        window.isHidden = true
    }

    /// The real lock (as `FearlessApplication.dropSession` presents it for the idle lock and the background re-lock)
    /// while a request window is key: the PIN goes on the app's own window, stays visible when the request window
    /// hides, and outlives the request flow ending.
    func testRealLock_whenTheRequestWindowIsKey_thenThePinCoversTheAppAndOutlivesTheRequest() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let notificationCenter = NotificationCenter()
        let lockState = ApplicationLockState(notificationCenter: notificationCenter)
        let mainRoot = UIViewController()
        let mainWindow = FearlessWindow(windowScene: scene)
        mainWindow.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        mainWindow.rootViewController = mainRoot
        mainWindow.makeKeyAndVisible()
        defer { mainWindow.isHidden = true }

        let router = WalletConnectCoordinatorRouterImpl(
            lockState: lockState,
            notificationCenter: notificationCenter,
            windowScene: { scene }
        )
        router.setRoot(controller: UIViewController())
        let requestWindow = try XCTUnwrap(router.coveringWindow)
        defer { requestWindow.isHidden = true }
        spinRunLoop(0.5)
        XCTAssertTrue(requestWindow.isKeyWindow, "A request on screen makes its window key")
        XCTAssertTrue(SceneWindowFinder.activeWindow(from: scene) === requestWindow)

        let pin = UIViewController()
        XCTAssertTrue(SceneWindowFinder.mainWindow(from: scene) === mainWindow)
        let presented = FearlessApplication.presentLock(
            on: SceneWindowFinder.mainWindow(from: scene),
            lockState: lockState
        ) { pin }
        spinRunLoop(0.5)

        XCTAssertTrue(presented === pin)
        XCTAssertTrue(mainRoot.presentedViewController === pin, "The PIN goes on the app's own window")
        XCTAssertTrue(lockState.isLocked)
        XCTAssertTrue(requestWindow.isHidden, "The request window waits behind the lock")
        XCTAssertTrue(pin.viewIfLoaded?.window === mainWindow, "The PIN is in the app's window")
        XCTAssertFalse(mainWindow.isHidden, "The PIN stays visible")
        XCTAssertTrue(mainWindow.isKeyWindow, "The PIN takes the keyboard")

        // The request flow ending dismisses its own window only: the PIN and the lock stay.
        let dismissed = expectation(description: "the request window is dismissed")
        router.dismiss { dismissed.fulfill() }
        wait(for: [dismissed], timeout: 5)
        XCTAssertTrue(mainRoot.presentedViewController === pin)
        XCTAssertTrue(lockState.isLocked)
    }

    func testRequestSheet_whenItsWindowHidesForTheLock_thenTheRequestIsNotRejected() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.windowLevel = .alert + 1
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let output = SessionSheetOutputSpy()
        let sheet = WalletConnectSessionViewController(output: output, localizationManager: nil)

        window.rootViewController?.present(sheet, animated: false)
        spinRunLoop(0.3)
        window.isHidden = true
        spinRunLoop(0.3)
        XCTAssertTrue(WalletConnectSheetVisibility.isHiddenWithItsWindow(sheet))
        XCTAssertEqual(output.disappearances, 0, "Hidden by the lock, the request is still open")

        window.isHidden = false
        sheet.dismiss(animated: false)
        spinRunLoop(0.3)
        XCTAssertEqual(output.disappearances, 1, "Closing the sheet answers the request")
        XCTAssertFalse(WalletConnectSheetVisibility.isHiddenWithItsWindow(sheet))
    }

    func testCheckPincode_whenThePinIsAccepted_thenTheLockEnds() {
        let lockState = ApplicationLockState(notificationCenter: NotificationCenter())
        let lockScreen = UIViewController()
        lockState.lock(with: lockScreen)
        XCTAssertTrue(lockState.isLocked)

        CheckPincodeWireframe(lockState: lockState).showMain(from: nil)

        XCTAssertFalse(lockState.isLocked)
    }

    func testLockState_whenThePinScreenIsGone_thenTheAppIsNotLocked() {
        let lockState = ApplicationLockState(notificationCenter: NotificationCenter())
        var lockScreen: UIViewController? = UIViewController()
        lockState.lock(with: lockScreen!)

        lockScreen = nil

        XCTAssertFalse(lockState.isLocked)
    }

    // MARK: - Helpers

    private func makeInteractor(
        signer: SignerSpy,
        service: WalletConnectServiceSpy,
        authorizer: WalletConnectSigningAuthorizing
    ) throws -> (WalletConnectConfirmationInteractor, WalletConnectSigningRequest) {
        let keystore = InMemoryKeychain()
        let wallet = try WalletConnectTestFixtures.ethereumWallet(seed: 0x09, keystore: keystore)
        let chain = WalletConnectTestFixtures.ethereumChain()
        let blockchain = try WalletConnectTestFixtures.ethereumBlockchain()
        let request = try WalletConnectTestFixtures.request(
            method: .ethereumPersonalSign,
            params: "[\"0x00\", \"\(wallet.addressHex)\"]",
            chain: blockchain
        )
        let signingRequest = WalletConnectSigningRequest(
            request: request,
            method: .ethereumPersonalSign,
            chain: chain,
            wallet: wallet.wallet,
            account: try XCTUnwrap(wallet.wallet.fetch(for: chain.accountRequest())),
            content: .ethereumMessage(WalletConnectMessage(bytes: Data([0x00]))),
            preview: "",
            rawDetails: .null
        )
        let session = try WalletConnectTestFixtures.session(approving: [(blockchain, wallet.addressHex)])

        let interactor = WalletConnectConfirmationInteractor(
            walletConnect: service,
            inputData: WalletConnectConfirmationInputData(
                signingRequest: signingRequest,
                session: session,
                verification: .verified
            ),
            signer: signer,
            authorizer: authorizer
        )
        return (interactor, signingRequest)
    }

    static func makeRequest() throws -> Request {
        try Request(
            topic: "walletconnect-lock",
            method: WalletConnectMethod.ethereumPersonalSign.rawValue,
            params: AnyCodable(["0x00", "0x00"]),
            chainId: XCTUnwrap(Blockchain("eip155:1"))
        )
    }

    private func spin(timeout: TimeInterval = 3, _ condition: () -> Bool) throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertTrue(condition(), "timed out")
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func hostInAppScene() throws -> (UIWindow, HostViewController) {
        // Presentations only complete in a window of the host app's scene.
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let root = HostViewController()
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = root
        window.makeKeyAndVisible()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        return (window, root)
    }
}

private final class CoordinatorFixture {
    let lockState: ApplicationLockState
    let lockScreen = UIViewController()
    let router = RouterSpy()
    let service = WalletConnectServiceSpy()
    /// Kept pending: nothing is presented on the host app.
    let requestEndedNotice = WalletConnectNoticePresenter(
        topViewController: { nil },
        isApplicationActive: { false },
        makeViewModel: { locale in WalletConnectNoticePresenter.requestEndedViewModel(locale: locale) }
    )
    private(set) var flows: [FlowSpy] = []
    var coordinator: WalletConnectCoordinator!

    init() {
        let notificationCenter = NotificationCenter()
        lockState = ApplicationLockState(notificationCenter: notificationCenter)
        coordinator = WalletConnectCoordinator(
            walletConnect: service,
            router: router,
            lockState: lockState,
            notificationCenter: notificationCenter,
            isApplicationActive: { true },
            requestEndedNotice: requestEndedNotice,
            makeRequestFlow: { [unowned self] router, _, _, _ in
                let flow = FlowSpy(router: router as? RouterSpy)
                flows.append(flow)
                return flow
            },
            makeProposalFlow: { [unowned self] router, _, _ in
                let flow = FlowSpy(router: router as? RouterSpy)
                flows.append(flow)
                return flow
            }
        )
    }
}

private final class FlowSpy: DefaultCoordinator, CoordinatorFinishOutput, WalletConnectSigningFlow {
    var finishFlow: (() -> Void)?
    var isSigning = false
    private weak var router: RouterSpy?
    private(set) var starts = 0

    init(router: RouterSpy?) {
        self.router = router
    }

    override func start() {
        starts += 1
        router?.isBusy = true
    }
}

private final class RouterSpy: WalletConnectCoordinatorRouter {
    var isBusy = false
    private(set) var dismissals = 0

    func setRoot(controller _: UIViewController) {}
    func present(controller _: UIViewController) {}

    func dismiss(completion: (() -> Void)?) {
        dismissals += 1
        isBusy = false
        completion?()
    }
}

private final class AuthorizerStub: WalletConnectSigningAuthorizing {
    let result: Bool
    private(set) var calls = 0

    init(result: Bool) {
        self.result = result
    }

    func authorize() async -> Bool {
        calls += 1
        return result
    }
}

private final class SignerSpy: WalletConnectSigner {
    private(set) var requests: [WalletConnectSigningRequest] = []

    func sign(request: WalletConnectSigningRequest) async throws -> AnyCodable {
        requests.append(request)
        return AnyCodable("0x5167")
    }
}

final class WalletConnectServiceSpy: WalletConnectService, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedSignDecisions: [WalletConnectSignDecision] = []
    private var recordedProposalDecisions: [WalletConnectProposalDecision] = []
    /// Decisions arrive from tasks on any thread.
    var signDecisions: [WalletConnectSignDecision] {
        lock.lock()
        defer { lock.unlock() }
        return recordedSignDecisions
    }

    var proposalDecisions: [WalletConnectProposalDecision] {
        lock.lock()
        defer { lock.unlock() }
        return recordedProposalDecisions
    }

    private(set) var disconnectedTopics: [String] = []
    private(set) var disconnectAllCalls = 0
    private(set) var pendingChecks = 0
    var sessions: [Session] = []
    /// Answers `isPending(request:)`, one value per check; the last one repeats.
    var pendingAnswers: [Bool] = [true]
    /// Thrown by `submit(signDecision:)` for a signature.
    var signedSubmitError: Error?

    func setup() {}
    func throttle() {}
    func set(listener _: WalletConnectServiceDelegate) {}
    func connect(uri _: String) async throws {}
    func disconnect(topic: String) async throws {
        disconnectedTopics.append(topic)
    }

    func disconnectAll() async throws {
        disconnectAllCalls += 1
    }

    func getSessions() -> [Session] { sessions }
    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] { [] }

    func isPending(request _: Request) async -> Bool {
        let answer = pendingAnswers[min(pendingChecks, pendingAnswers.count - 1)]
        pendingChecks += 1
        return answer
    }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        record(proposalDecision)
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        if case .signed = signDecision, let signedSubmitError = signedSubmitError {
            throw signedSubmitError
        }
        record(signDecision)
    }

    private func record(_ decision: WalletConnectProposalDecision) {
        lock.lock()
        recordedProposalDecisions.append(decision)
        lock.unlock()
    }

    private func record(_ decision: WalletConnectSignDecision) {
        lock.lock()
        recordedSignDecisions.append(decision)
        lock.unlock()
    }
}

private final class HostViewController: UIViewController, ControllerBackedProtocol {}

private final class SessionSheetOutputSpy: WalletConnectSessionViewOutput {
    private(set) var disappearances = 0

    func didLoad(view _: WalletConnectSessionViewInput) {}
    func viewDidDisappear() {
        disappearances += 1
    }

    func closeButtonDidTapped() {}
    func actionButtonDidTapped() {}
}

private func spinRunLoop(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
}
