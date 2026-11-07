import FearlessWalletConnect
import Foundation
import SoraKeystore
import UIKit
import XCTest
@testable import fearless

/// What signing for apps rests on now that it is on: pairing links (`wc:` and `fearless://wc?uri=`), the remote
/// per-network veto (absent keys keep signing on, an explicit `false` pauses it), and the notices that tell the user
/// a request was declined.
final class WalletConnectSigningGateTests: XCTestCase {
    private static let pairing =
        "wc:7f6e504bfad60b485450578e05678ed3e8e8c4751d3c6160be17160d63ec90f9@2?relay-protocol=irn" +
        "&symKey=587d5484ce2a2a6ee3ba1962fdd7e8588e06200c46823bd18fbd67def96ad303&expiryTimestamp=1894000000"

    override func tearDown() {
        MultiChainFeaturePolicy.liftRememberedVetoes()
        super.tearDown()
    }

    // MARK: - Links

    func testLinks_readWcURIsAndFearlessLinks() throws {
        let encoded = try XCTUnwrap(Self.pairing.addingPercentEncoding(withAllowedCharacters: .alphanumerics))

        XCTAssertEqual(WalletConnectURLHandler.link(from: try url(Self.pairing)), .pairing(Self.pairing))
        XCTAssertEqual(WalletConnectURLHandler.link(from: try url("WC:" + Self.pairing.dropFirst(3))), .pairing(Self.pairing))
        XCTAssertEqual(WalletConnectURLHandler.link(from: try url("fearless://wc?uri=" + encoded)), .pairing(Self.pairing))
        // Some dApps do not encode the URI: its own query must survive.
        XCTAssertEqual(WalletConnectURLHandler.link(from: try url("fearless://wc?uri=" + Self.pairing)), .pairing(Self.pairing))
        // A paired dApp's request link has no key: it only brings the wallet forward.
        XCTAssertEqual(WalletConnectURLHandler.link(from: try url("wc:7f6e504bfad60b48@2")), .openWallet)

        for other in [
            "fearless://tc?v=2&id=1",
            "fearless://wc?url=" + encoded,
            "fearless://wc?uri=https%3A%2F%2Fexample.org",
            "fearless://polkamarkt?market=1",
            "tc://?v=2&id=1",
            "https://fearlesswallet.io/wc?uri=" + encoded,
            "irohaconnect://connect"
        ] {
            XCTAssertNil(WalletConnectURLHandler.link(from: try url(other)), other)
        }
    }

    func testHandler_pairsOnTheMainQueueAndClaimsOnlyWalletConnectLinks() throws {
        let paired = expectation(description: "paired")
        var uris: [String] = []
        let handler = WalletConnectURLHandler { uri in
            XCTAssertTrue(Thread.isMainThread)
            uris.append(uri)
            paired.fulfill()
        }

        XCTAssertTrue(handler.handle(url: try url(Self.pairing)))
        XCTAssertTrue(handler.handle(url: try url("wc:7f6e504bfad60b48@2")))
        XCTAssertFalse(handler.handle(url: try url("fearless://tc?v=2&id=1")))

        wait(for: [paired], timeout: 3)
        XCTAssertEqual(uris, [Self.pairing])
    }

    func testLinkBeforeSetup_waitsForTheServiceAndPairsOnce() throws {
        let pairings = LinkPairingRecorder()
        let service = WalletConnectServiceImpl(
            signingPolicy: .production,
            pair: pairings.record,
            clientFactory: { _ in Self.offlineClient() },
            notificationCenter: NotificationCenter()
        )

        service.pairFromLink(uri: Self.pairing)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertTrue(pairings.uris.isEmpty, "Nothing pairs before the service is set up")

        service.setup()
        try spin { pairings.uris.count == 1 }
        XCTAssertEqual(pairings.uris, [try WalletConnectURI(uriString: Self.pairing).absoluteString])
        service.throttle()
    }

    func testLinkThatCannotPair_isReportedToTheListeners() throws {
        let service = WalletConnectServiceImpl(
            signingPolicy: .production,
            pair: { _ in throw WalletConnectClient.ClientError.pairingExpired },
            clientFactory: { _ in Self.offlineClient() },
            notificationCenter: NotificationCenter()
        )
        let listener = GateListener()
        service.set(listener: listener)
        service.setup()

        service.pairFromLink(uri: Self.pairing)

        try spin { !listener.pairingErrors.isEmpty }
        let message = WalletConnectNoticePresenter.pairingFailureMessage(
            for: try XCTUnwrap(listener.pairingErrors.first),
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(message, "This connection link has expired. Ask the app for a new one.")
        service.throttle()
    }

    func testTheSameLinkOpenedTwice_isNotReportedAsAFailure() throws {
        let attempts = LinkPairingRecorder()
        let service = WalletConnectServiceImpl(
            signingPolicy: .production,
            pair: { uri in
                attempts.record(uri.absoluteString)
                throw WalletConnectClient.ClientError.pairingAlreadyActive
            },
            clientFactory: { _ in Self.offlineClient() },
            notificationCenter: NotificationCenter()
        )
        let listener = GateListener()
        service.set(listener: listener)
        service.setup()

        service.pairFromLink(uri: Self.pairing)

        try spin { attempts.uris.count == 1 }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertTrue(listener.pairingErrors.isEmpty)
        service.throttle()
    }

    // MARK: - The remote veto

    func testVeto_followsTheRequestsNetworkAndRefusesOtherNetworks() throws {
        let evm = try XCTUnwrap(Blockchain("eip155:1"))
        let polkadot = try XCTUnwrap(Blockchain("polkadot:91b171bb158e2d3848fa23a9f1c25182"))
        let solana = try XCTUnwrap(Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"))
        let on = FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: false)

        XCTAssertTrue(WalletConnectSigningVeto.isSigningAllowed(on: evm, policy: on))
        XCTAssertTrue(WalletConnectSigningVeto.isSigningAllowed(on: polkadot, policy: on))
        XCTAssertFalse(WalletConnectSigningVeto.isSigningAllowed(on: solana, policy: on))

        let evmPaused = FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: false, evmDappSigningEnabled: false)
        XCTAssertFalse(WalletConnectSigningVeto.isSigningAllowed(on: evm, policy: evmPaused))
        XCTAssertTrue(WalletConnectSigningVeto.isSigningAllowed(on: polkadot, policy: evmPaused))

        let polkadotPaused = FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: false, polkadotDappSigningEnabled: false)
        XCTAssertTrue(WalletConnectSigningVeto.isSigningAllowed(on: evm, policy: polkadotPaused))
        XCTAssertFalse(WalletConnectSigningVeto.isSigningAllowed(on: polkadot, policy: polkadotPaused))
    }

    func testRemoteVeto_whenRemembered_pausesSigningForItsNetworkOnly() throws {
        let decoder = GithubJSONDecoder()
        MultiChainFeaturePolicy.update(
            try decoder.decode(FeatureToggleConfig.self, from: Data(#"{"evm_dapp_signing_enabled":false}"#.utf8))
        )

        XCTAssertFalse(WalletConnectSigningVeto.isSigningAllowed(on: try XCTUnwrap(Blockchain("eip155:56"))))
        XCTAssertTrue(
            WalletConnectSigningVeto.isSigningAllowed(on: try XCTUnwrap(Blockchain("polkadot:91b171bb158e2d3848fa23a9f1c25182")))
        )
    }

    func testPausedNetwork_declinesTheRequestBeforeAnythingOpens() throws {
        let declined = expectation(description: "the dApp is told the request was declined")
        let responses = GateResponseRecorder { declined.fulfill() }
        let service = WalletConnectServiceImpl(
            signingPolicy: .production,
            respond: responses.record,
            isSigningAllowed: { $0.namespace != "eip155" }
        )
        let listener = GateListener()
        service.set(listener: listener)
        let request = try WalletConnectAuthorizationAndLockTests.makeRequest()

        service.handle(request: request, session: nil, context: VerifyContext(
            origin: "https://app.example.org",
            validation: .valid,
            verifyUrl: "https://verify.walletconnect.org"
        ))

        wait(for: [declined], timeout: 3)
        XCTAssertEqual(responses.recorded.map(\.response), [.error(.userRejected)])
        XCTAssertEqual(listener.pausedRequests, [request])
        XCTAssertTrue(listener.signRequests.isEmpty)
        XCTAssertTrue(listener.unavailableRequests.isEmpty)
    }

    func testSigningOn_opensTheConfirmationForANetworkThatIsNotPaused() throws {
        let responses = GateResponseRecorder()
        let service = WalletConnectServiceImpl(
            signingPolicy: .production,
            respond: responses.record,
            isSigningAllowed: { _ in true }
        )
        let listener = GateListener()
        service.set(listener: listener)
        let request = try WalletConnectAuthorizationAndLockTests.makeRequest()

        service.handle(request: request, session: nil, context: nil)

        XCTAssertEqual(listener.signRequests, [request])
        XCTAssertTrue(listener.pausedRequests.isEmpty)
        XCTAssertTrue(responses.recorded.isEmpty)
    }

    // MARK: - The confirmation

    func testApprove_whenTheNetworkIsPaused_thenNoPinIsAskedAndNothingIsSigned() async throws {
        let fixture = try ConfirmationFixture(isSigningAllowed: { _ in false })

        do {
            _ = try await fixture.interactor.approve()
            XCTFail("A paused network must not be signed for")
        } catch WalletConnectSigningError.paused {}

        XCTAssertEqual(fixture.authorizer.calls, 0)
        XCTAssertTrue(fixture.signer.requests.isEmpty)
        XCTAssertTrue(fixture.service.signDecisions.isEmpty)
    }

    func testApprove_whenTheNetworkIsPausedWhileThePinIsAsked_thenNothingIsSigned() async throws {
        var checks = 0
        let fixture = try ConfirmationFixture(isSigningAllowed: { _ in
            checks += 1
            return checks == 1
        })

        do {
            _ = try await fixture.interactor.approve()
            XCTFail("A veto that arrives during the PIN must stop the signature")
        } catch WalletConnectSigningError.paused {}

        XCTAssertEqual(fixture.authorizer.calls, 1)
        XCTAssertTrue(fixture.signer.requests.isEmpty)
        XCTAssertTrue(fixture.service.signDecisions.isEmpty)
    }

    func testApprove_whenAllowedAndConfirmed_thenSignsOnce() async throws {
        let fixture = try ConfirmationFixture(isSigningAllowed: { _ in true })

        _ = try await fixture.interactor.approve()

        XCTAssertEqual(fixture.authorizer.calls, 1)
        XCTAssertEqual(fixture.signer.requests.count, 1)
        XCTAssertEqual(fixture.service.signDecisions.count, 1)
    }

    func testSigningAuthorizer_asksTheSubmissionAuthorizerFromTheConfirmation() async throws {
        let keystore = InMemoryKeychain()
        try keystore.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        let submission = SubmissionAuthorizerSpy(result: true)
        let authorizer = WalletConnectSigningAuthorizer(keystore: keystore, submissionAuthorizer: submission)
        let view = GateHostViewController()
        authorizer.view = view

        let authorized = await authorizer.authorize()

        XCTAssertTrue(authorized)
        XCTAssertEqual(submission.calls, 1)
        XCTAssertTrue(submission.views.first === view)
        XCTAssertFalse(authorizer.isAuthorizing)
    }

    func testSigningAuthorizer_whenTheSubmissionIsNotAuthorized_thenRefuses() async throws {
        let keystore = InMemoryKeychain()
        try keystore.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        let authorizer = WalletConnectSigningAuthorizer(
            keystore: keystore,
            submissionAuthorizer: SubmissionAuthorizerSpy(result: false)
        )
        authorizer.view = GateHostViewController()

        let authorized = await authorizer.authorize()

        XCTAssertFalse(authorized)
    }

    // MARK: - Notices

    func testCoordinator_showsOneNoticeForPausedRequestsAndForFailedLinks() throws {
        let paused = WalletConnectNoticePresenter(
            topViewController: { nil },
            isApplicationActive: { true },
            makeViewModel: { locale, _ in WalletConnectNoticePresenter.signingPausedViewModel(locale: locale) }
        )
        let failedLink = WalletConnectNoticePresenter(
            topViewController: { nil },
            isApplicationActive: { true },
            makeViewModel: { locale, message in
                SheetAlertPresentableViewModel(
                    title: "", message: message ?? "", actions: [], closeAction: nil, icon: nil
                )
            }
        )
        let notificationCenter = NotificationCenter()
        let coordinator = WalletConnectCoordinator(
            walletConnect: WalletConnectServiceSpy(),
            lockState: ApplicationLockState(notificationCenter: notificationCenter),
            notificationCenter: notificationCenter,
            isApplicationActive: { true },
            signingPausedNotice: paused,
            pairingFailedNotice: failedLink
        )

        coordinator.signingPaused(request: try WalletConnectAuthorizationAndLockTests.makeRequest(), session: nil)
        coordinator.pairingFailed(error: WalletConnectClient.ClientError.pairingExpired)

        // No screen to present on yet: both notices wait, and nothing opened a request.
        XCTAssertTrue(paused.isNoticePending)
        XCTAssertTrue(failedLink.isNoticePending)
        XCTAssertTrue(coordinator.childCoordinators.isEmpty)
    }

    func testNoticeTexts_sayNothingWasSigned() {
        let english = Locale(identifier: "en")
        let paused = WalletConnectNoticePresenter.signingPausedViewModel(locale: english)

        XCTAssertEqual(paused.title, "Signing is paused")
        XCTAssertTrue(paused.message?.contains("nothing was signed") == true)
        XCTAssertEqual(
            WalletConnectNoticePresenter.pairingFailureMessage(
                for: ConvenienceContentError(title: "t", message: "The link is for an old version"),
                locale: english
            ),
            "The link is for an old version"
        )
        XCTAssertEqual(
            WalletConnectNoticePresenter.pairingFailureMessage(for: GateTestError.failed, locale: english),
            "Fearless couldn't use this connection link. Ask the app for a new one and try again."
        )
    }

    // MARK: - Helpers

    private func url(_ string: String) throws -> URL {
        try XCTUnwrap(URL(string: string), string)
    }

    private func spin(timeout: TimeInterval = 3, _ condition: () -> Bool) throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertTrue(condition(), "timed out")
    }

    private static func offlineClient() -> WalletConnectClient {
        let store = InMemoryWalletConnectStore()
        return WalletConnectClient(
            configuration: .init(
                projectId: "offline",
                metadata: AppMetadata(name: "Fearless", description: "", url: "https://fearlesswallet.io", icons: []),
                bundleId: nil,
                userAgent: "wc-2/fearless-wallet-ios-tests"
            ),
            stateStore: store,
            secretStore: store,
            transportFactory: OfflineRelayTransportFactory()
        )
    }
}

private enum GateTestError: Error {
    case failed
}

private final class LinkPairingRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var uris: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ uri: WalletConnectURI) async throws {
        record(uri.absoluteString)
    }

    func record(_ uri: String) {
        lock.lock()
        recorded.append(uri)
        lock.unlock()
    }
}

private final class GateResponseRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(request: Request, response: RPCResult)] = []
    private let onRecord: (() -> Void)?

    init(onRecord: (() -> Void)? = nil) {
        self.onRecord = onRecord
    }

    var recorded: [(request: Request, response: RPCResult)] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func record(_ request: Request, _ response: RPCResult) async throws {
        lock.lock()
        entries.append((request, response))
        lock.unlock()
        onRecord?()
    }
}

private final class GateListener: WalletConnectServiceDelegate {
    private(set) var signRequests: [Request] = []
    private(set) var pausedRequests: [Request] = []
    private(set) var unavailableRequests: [Request] = []
    private(set) var pairingErrors: [Error] = []

    func sign(request: Request, session _: Session?, verification _: WalletConnectVerification) {
        signRequests.append(request)
    }

    func signingPaused(request: Request, session _: Session?) {
        pausedRequests.append(request)
    }

    func signingUnavailable(request: Request, session _: Session?) {
        unavailableRequests.append(request)
    }

    func pairingFailed(error: Error) {
        pairingErrors.append(error)
    }
}

private final class GateAuthorizerStub: WalletConnectSigningAuthorizing {
    private(set) var calls = 0

    func authorize() async -> Bool {
        calls += 1
        return true
    }
}

private final class GateSignerSpy: WalletConnectSigner {
    private(set) var requests: [WalletConnectSigningRequest] = []

    func sign(request: WalletConnectSigningRequest) async throws -> AnyCodable {
        requests.append(request)
        return AnyCodable("0x5167")
    }
}

private final class ConfirmationFixture {
    let signer = GateSignerSpy()
    let service = WalletConnectServiceSpy()
    let authorizer = GateAuthorizerStub()
    let interactor: WalletConnectConfirmationInteractor

    init(isSigningAllowed: @escaping (Blockchain) -> Bool) throws {
        let keystore = InMemoryKeychain()
        let wallet = try WalletConnectTestFixtures.ethereumWallet(seed: 0x0A, keystore: keystore)
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
        interactor = WalletConnectConfirmationInteractor(
            walletConnect: service,
            inputData: WalletConnectConfirmationInputData(
                signingRequest: signingRequest,
                session: try WalletConnectTestFixtures.session(approving: [(blockchain, wallet.addressHex)]),
                verification: .verified
            ),
            signer: signer,
            authorizer: authorizer,
            isSigningAllowed: isSigningAllowed
        )
    }
}

private final class SubmissionAuthorizerSpy: SubmissionAuthorizing {
    let result: Bool
    private(set) var calls = 0
    private(set) var views: [AnyObject] = []

    init(result: Bool) {
        self.result = result
    }

    func authorizeSubmission(from view: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        calls += 1
        if let view = view {
            views.append(view)
        }
        completion(result)
    }
}

private final class GateHostViewController: UIViewController, ControllerBackedProtocol {}
