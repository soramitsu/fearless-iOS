import Commons
import Foundation
import SoraKeystore
import UIKit
import WalletConnectSign
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

        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil)

        XCTAssertEqual(fixture.flows.count, 1)
        XCTAssertEqual(fixture.flows.first?.starts, 0, "Nothing may appear above the PIN screen")

        fixture.lockState.unlock()

        XCTAssertEqual(fixture.flows.first?.starts, 1)
    }

    func testCoordinator_whenTheSameRequestArrivesAgain_thenItIsShownOnce() throws {
        let fixture = CoordinatorFixture()
        let request = try Self.makeRequest()

        fixture.coordinator.sign(request: request, session: nil)
        fixture.coordinator.sign(request: request, session: nil)

        XCTAssertEqual(fixture.flows.count, 1)

        fixture.flows.first?.finishFlow?()
        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil)

        XCTAssertEqual(fixture.flows.count, 2)
        XCTAssertEqual(fixture.flows.last?.starts, 1)
    }

    func testCoordinator_whenARequestIsOnScreen_thenTheNextOneWaits() throws {
        let fixture = CoordinatorFixture()

        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil)
        fixture.coordinator.sign(request: try Self.makeRequest(), session: nil)

        XCTAssertEqual(fixture.flows.map(\.starts), [1, 0])

        fixture.flows.first?.finishFlow?()

        XCTAssertEqual(fixture.flows.map(\.starts), [1, 1])
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
                session: session
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
    private(set) var flows: [FlowSpy] = []
    var coordinator: WalletConnectCoordinator!

    init() {
        let notificationCenter = NotificationCenter()
        lockState = ApplicationLockState(notificationCenter: notificationCenter)
        coordinator = WalletConnectCoordinator(
            walletConnect: WalletConnectServiceSpy(),
            router: router,
            lockState: lockState,
            notificationCenter: notificationCenter,
            isApplicationActive: { true },
            makeRequestFlow: { [unowned self] router, _, _ in
                let flow = FlowSpy(router: router as? RouterSpy)
                flows.append(flow)
                return flow
            },
            makeProposalFlow: { [unowned self] router, _ in
                let flow = FlowSpy(router: router as? RouterSpy)
                flows.append(flow)
                return flow
            }
        )
    }
}

private final class FlowSpy: DefaultCoordinator, CoordinatorFinishOutput {
    var finishFlow: (() -> Void)?
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

    func setRoot(controller _: UIViewController) {}
    func present(controller _: UIViewController) {}

    func dismiss(completion: (() -> Void)?) {
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

final class WalletConnectServiceSpy: WalletConnectService {
    private(set) var signDecisions: [WalletConnectSignDecision] = []
    private(set) var proposalDecisions: [WalletConnectProposalDecision] = []

    func setup() {}
    func throttle() {}
    func set(listener _: WalletConnectServiceDelegate) {}
    func connect(uri _: String) async throws {}
    func disconnect(topic _: String) async throws {}
    func getSessions() -> [Session] { [] }
    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] { [] }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        proposalDecisions.append(proposalDecision)
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        signDecisions.append(signDecision)
    }
}

private final class HostViewController: UIViewController, ControllerBackedProtocol {}
