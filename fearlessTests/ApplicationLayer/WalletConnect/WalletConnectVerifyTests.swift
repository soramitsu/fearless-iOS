import FearlessWalletConnect
import Foundation
import XCTest
@testable import fearless

/// WalletConnect Verify results reach the proposal, the request sheet and the
/// confirmation, and apps Verify flags as known scams are declined before anything opens.
final class WalletConnectVerifyTests: XCTestCase {
    func testVerification_mapsEveryVerifyResult() {
        XCTAssertEqual(WalletConnectVerification(context: VerifyContext(origin: "https://a.org", validation: .valid, verifyUrl: "https://verify.walletconnect.org")), .verified)
        XCTAssertEqual(
            WalletConnectVerification(context: VerifyContext(origin: "https://a.org", validation: .invalid, verifyUrl: "https://verify.walletconnect.org")),
            .mismatch(origin: "https://a.org")
        )
        XCTAssertEqual(WalletConnectVerification(context: VerifyContext(origin: "https://a.org", validation: .scam, verifyUrl: "https://verify.walletconnect.org")), .scam)
        XCTAssertEqual(WalletConnectVerification(context: VerifyContext(origin: "https://a.org", validation: .unknown, verifyUrl: "https://verify.walletconnect.org")), .unverified)
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

        service.handle(proposal: proposal, context: VerifyContext(origin: "https://drainer.example", validation: .scam, verifyUrl: "https://verify.walletconnect.org"))

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

        service.handle(proposal: try Self.makeProposal(), context: VerifyContext(origin: "https://app.example.org", validation: .invalid, verifyUrl: "https://verify.walletconnect.org"))

        XCTAssertEqual(listener.proposals.map(\.verification), [.mismatch(origin: "https://app.example.org")])
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
                context: VerifyContext(origin: "https://drainer.example", validation: .scam, verifyUrl: "https://verify.walletconnect.org")
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
                context: VerifyContext(origin: "https://app.example.org", validation: .valid, verifyUrl: "https://verify.walletconnect.org")
            )

            XCTAssertEqual(listener.signRequests.map(\.verification), [.verified])
            XCTAssertTrue(responses.results.isEmpty)
        }
    #endif

    func testRequest_whenFlaggedAsScamWhileSigningIsUnavailable_thenTheScamIsReported() throws {
        let declined = expectation(description: "the request is declined")
        let responses = VerifyResponseRecorder { declined.fulfill() }
        let service = WalletConnectServiceImpl(signingPolicy: .disabled, respond: responses.record)
        let listener = VerifyListener()
        service.set(listener: listener)

        service.handle(
            request: try WalletConnectAuthorizationAndLockTests.makeRequest(),
            session: nil,
            context: VerifyContext(origin: "https://drainer.example", validation: .scam, verifyUrl: "https://verify.walletconnect.org")
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
            let mismatch = WalletConnectVerification.mismatch(origin: "https://x.example")
            for verification in [WalletConnectVerification.verified, .unverified, mismatch, .scam] {
                XCTAssertNotEqual(verification.title(for: locale), verification.title(for: english), identifier)
            }
            for verification in [WalletConnectVerification.unverified, mismatch] {
                XCTAssertNotEqual(verification.warning(for: locale), verification.warning(for: english), identifier)
            }
            XCTAssertNotEqual(
                WalletConnectNoticePresenter.signingPausedViewModel(locale: locale).message,
                WalletConnectNoticePresenter.signingPausedViewModel(locale: english).message,
                identifier
            )
            XCTAssertNotEqual(
                WalletConnectNoticePresenter.pairingFailureMessage(for: TestError.failed, locale: locale),
                WalletConnectNoticePresenter.pairingFailureMessage(for: TestError.failed, locale: english),
                identifier
            )
            XCTAssertNotEqual(
                WalletConnectNoticePresenter.scamBlockedViewModel(origin: "x", locale: locale).message,
                WalletConnectNoticePresenter.scamBlockedViewModel(origin: "x", locale: english).message,
                identifier
            )
        }
    }

    func testAMismatchOrASiteVerifyCouldNotCheckAddsAWarning() {
        let english = Locale(identifier: "en")
        XCTAssertNotNil(WalletConnectVerification.mismatch(origin: "https://x.example").warning(for: english))
        XCTAssertNotNil(WalletConnectVerification.unverified.warning(for: english))
        XCTAssertNil(WalletConnectVerification.verified.warning(for: english))
        XCTAssertNil(WalletConnectVerification.scam.warning(for: english))
    }

    func testWebsite_isWhereTheRequestCameFromWhenItIsNotTheClaimedSite() {
        let claimed = "https://app.uniswap.org/swap"
        XCTAssertEqual(WalletConnectVerification.verified.website(claimed: claimed), "app.uniswap.org")
        XCTAssertEqual(WalletConnectVerification.unverified.website(claimed: claimed), "app.uniswap.org")
        XCTAssertEqual(
            WalletConnectVerification.mismatch(origin: "https://uniswap-airdrop.example").website(claimed: claimed),
            "uniswap-airdrop.example"
        )
        // Verify reported a mismatch without saying where from: only the claim is left to show.
        XCTAssertEqual(WalletConnectVerification.mismatch(origin: "").website(claimed: claimed), "app.uniswap.org")
    }

    // MARK: - Helpers

    static func makeProposal() throws -> Session.Proposal {
        Session.Proposal(
            id: 1_794_000_000_000_001,
            pairingTopic: "verify-pairing",
            proposer: AppMetadata(name: "Example", description: "", url: "https://app.example.org", icons: []),
            requiredNamespaces: [:],
            optionalNamespaces: nil,
            sessionProperties: nil,
            expiryDate: Date(timeIntervalSinceNow: 300)
        )
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

private enum TestError: Error {
    case failed
}
