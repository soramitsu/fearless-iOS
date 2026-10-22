import FearlessWalletConnect
import Foundation
import XCTest
@testable import fearless

/// WalletConnect Verify results reach the proposal, the request sheet and the
/// confirmation, and apps Verify flags as known scams are declined before anything opens.
final class WalletConnectVerifyTests: XCTestCase {
    func testVerification_mapsEveryVerifyResult() {
        XCTAssertEqual(WalletConnectVerification(context: VerifyContext(origin: "https://a.org", validation: .valid)), .verified)
        XCTAssertEqual(WalletConnectVerification(context: VerifyContext(origin: "https://a.org", validation: .invalid)), .mismatch)
        XCTAssertEqual(WalletConnectVerification(context: VerifyContext(origin: "https://a.org", validation: .scam)), .scam)
        XCTAssertEqual(WalletConnectVerification(context: VerifyContext(origin: nil, validation: .unknown)), .unverified)
        XCTAssertEqual(WalletConnectVerification(context: nil), .unverified)
    }

    // MARK: - Proposals

    func testProposal_whenFlaggedAsScam_thenItIsDeclinedAndNeverShown() throws {
        let declined = expectation(description: "the proposal is declined")
        let rejections = ProposalRejectionRecorder { declined.fulfill() }
        let service = WalletConnectServiceImpl(signingPolicy: .production, rejectProposal: rejections.record)
        let listener = VerifyListener()
        service.set(listener: listener)
        let proposal = try Self.makeProposal()

        service.handle(proposal: proposal, context: VerifyContext(origin: "https://drainer.example", validation: .scam))

        wait(for: [declined], timeout: 3)
        XCTAssertEqual(rejections.proposalIds, [proposal.id])
        XCTAssertTrue(listener.proposals.isEmpty)
        XCTAssertEqual(listener.blockedOrigins, ["drainer.example"])
    }

    func testProposal_whenNotFlagged_thenItIsShownWithItsVerification() throws {
        let rejections = ProposalRejectionRecorder()
        let service = WalletConnectServiceImpl(signingPolicy: .production, rejectProposal: rejections.record)
        let listener = VerifyListener()
        service.set(listener: listener)

        service.handle(proposal: try Self.makeProposal(), context: VerifyContext(origin: "https://app.example.org", validation: .invalid))

        XCTAssertEqual(listener.proposals.map(\.verification), [.mismatch])
        XCTAssertTrue(listener.blockedOrigins.isEmpty)
        XCTAssertTrue(rejections.proposalIds.isEmpty)
    }

    // MARK: - Requests

    #if DEBUG
        func testRequest_whenFlaggedAsScam_thenItIsDeclinedBeforeAnyConfirmation() throws {
            let declined = expectation(description: "the request is declined")
            let responses = VerifyResponseRecorder { declined.fulfill() }
            let service = WalletConnectServiceImpl(signingPolicy: .enabledForTests, respond: responses.record)
            let listener = VerifyListener()
            service.set(listener: listener)
            let request = try WalletConnectAuthorizationAndLockTests.makeRequest()

            service.handle(
                request: request,
                session: nil,
                context: VerifyContext(origin: "https://drainer.example", validation: .scam)
            )

            wait(for: [declined], timeout: 3)
            XCTAssertEqual(responses.results, [.error(.userRejected)])
            XCTAssertTrue(listener.signRequests.isEmpty)
            XCTAssertEqual(listener.blockedOrigins, ["drainer.example"])
        }

        func testRequest_whenVerified_thenOpensWithItsVerification() throws {
            let responses = VerifyResponseRecorder()
            let service = WalletConnectServiceImpl(signingPolicy: .enabledForTests, respond: responses.record)
            let listener = VerifyListener()
            service.set(listener: listener)

            service.handle(
                request: try WalletConnectAuthorizationAndLockTests.makeRequest(),
                session: nil,
                context: VerifyContext(origin: "https://app.example.org", validation: .valid)
            )

            XCTAssertEqual(listener.signRequests.map(\.verification), [.verified])
            XCTAssertTrue(responses.results.isEmpty)
        }
    #endif

    func testRequest_whenFlaggedAsScamWhileSigningIsUnavailable_thenTheScamIsReported() throws {
        let declined = expectation(description: "the request is declined")
        let responses = VerifyResponseRecorder { declined.fulfill() }
        let service = WalletConnectServiceImpl(signingPolicy: .production, respond: responses.record)
        let listener = VerifyListener()
        service.set(listener: listener)

        service.handle(
            request: try WalletConnectAuthorizationAndLockTests.makeRequest(),
            session: nil,
            context: VerifyContext(origin: "https://drainer.example", validation: .scam)
        )

        wait(for: [declined], timeout: 3)
        XCTAssertEqual(listener.blockedOrigins, ["drainer.example"])
        XCTAssertTrue(listener.unavailableRequests.isEmpty)
    }

    // MARK: - What the user sees

    func testScamNotice_namesTheAppAndOffersOnlyClose() {
        let viewModel = WalletConnectNoticePresenter.scamBlockedViewModel(
            origin: "drainer.example",
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(viewModel.title, "Request blocked")
        XCTAssertTrue(viewModel.message?.contains("drainer.example") == true)
        XCTAssertTrue(viewModel.actions.isEmpty)
    }

    func testVerificationTexts_areTranslatedInEveryShippedLocale() {
        let english = Locale(identifier: "en")
        let shipped = Bundle.main.localizations.filter { $0 != "en" && $0 != "Base" }
        XCTAssertFalse(shipped.isEmpty)

        for identifier in shipped {
            let locale = Locale(identifier: identifier)
            for verification in [WalletConnectVerification.verified, .unverified, .mismatch, .scam] {
                XCTAssertNotEqual(verification.title(for: locale), verification.title(for: english), identifier)
            }
            XCTAssertNotEqual(
                WalletConnectVerification.mismatch.warning(for: locale),
                WalletConnectVerification.mismatch.warning(for: english),
                identifier
            )
            XCTAssertNotEqual(
                WalletConnectNoticePresenter.scamBlockedViewModel(origin: "x", locale: locale).message,
                WalletConnectNoticePresenter.scamBlockedViewModel(origin: "x", locale: english).message,
                identifier
            )
        }
    }

    func testOnlyAMismatchAddsAWarning() {
        let english = Locale(identifier: "en")
        XCTAssertNotNil(WalletConnectVerification.mismatch.warning(for: english))
        XCTAssertNil(WalletConnectVerification.verified.warning(for: english))
        XCTAssertNil(WalletConnectVerification.unverified.warning(for: english))
    }

    // MARK: - Helpers

    static func makeProposal() throws -> Session.Proposal {
        let json = """
        {
            "id": "verify-proposal",
            "pairingTopic": "verify-pairing",
            "proposer": {"name": "Example", "description": "", "url": "https://app.example.org", "icons": []},
            "requiredNamespaces": {},
            "proposal": {
                "relays": [{"protocol": "irn"}],
                "proposer": {
                    "publicKey": "verify-key",
                    "metadata": {"name": "Example", "description": "", "url": "https://app.example.org", "icons": []}
                },
                "requiredNamespaces": {}
            }
        }
        """
        return try JSONDecoder().decode(Session.Proposal.self, from: Data(json.utf8))
    }
}

private final class VerifyListener: WalletConnectServiceDelegate {
    private(set) var proposals: [(proposal: Session.Proposal, verification: WalletConnectVerification)] = []
    private(set) var signRequests: [(request: Request, verification: WalletConnectVerification)] = []
    private(set) var unavailableRequests: [Request] = []
    private(set) var blockedOrigins: [String] = []

    func session(proposal: Session.Proposal, verification: WalletConnectVerification) {
        proposals.append((proposal, verification))
    }

    func sign(request: Request, session _: Session?, verification: WalletConnectVerification) {
        signRequests.append((request, verification))
    }

    func signingUnavailable(request: Request, session _: Session?) {
        unavailableRequests.append(request)
    }

    func blockedScam(origin: String) {
        blockedOrigins.append(origin)
    }
}

private final class ProposalRejectionRecorder {
    private let lock = NSLock()
    private var ids: [String] = []
    private let onRecord: () -> Void

    init(onRecord: @escaping () -> Void = {}) {
        self.onRecord = onRecord
    }

    var proposalIds: [String] {
        lock.lock()
        defer { lock.unlock() }
        return ids
    }

    func record(_ proposal: Session.Proposal) async throws {
        lock.lock()
        ids.append(proposal.id)
        lock.unlock()
        onRecord()
    }
}

private final class VerifyResponseRecorder {
    private let lock = NSLock()
    private var responses: [RPCResult] = []
    private let onRecord: () -> Void

    init(onRecord: @escaping () -> Void = {}) {
        self.onRecord = onRecord
    }

    var results: [RPCResult] {
        lock.lock()
        defer { lock.unlock() }
        return responses
    }

    func record(_: Request, _ response: RPCResult) async throws {
        lock.lock()
        responses.append(response)
        lock.unlock()
        onRecord()
    }
}
