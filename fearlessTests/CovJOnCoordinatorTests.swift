import XCTest
import UIKit
import SoraFoundation
import FearlessWalletConnect
@testable import fearless

final class CovJOnWcService: WalletConnectService, @unchecked Sendable {
    private let lock = NSLock()
    private var proposals: [WalletConnectProposalDecision] = []
    private var signs: [WalletConnectSignDecision] = []
    weak var listener: WalletConnectServiceDelegate?
    var proposalDecisions: [WalletConnectProposalDecision] { lock.lock(); defer { lock.unlock() }; return proposals }
    var signDecisions: [WalletConnectSignDecision] { lock.lock(); defer { lock.unlock() }; return signs }

    func setup() {}
    func throttle() {}
    func set(listener: WalletConnectServiceDelegate) { self.listener = listener }
    func connect(uri _: String) async throws {}
    func disconnect(topic _: String) async throws {}
    func disconnectAll() async throws {}
    func getSessions() -> [Session] { [] }
    func isPending(request _: Request) async -> Bool { true }
    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] { [] }
    func submit(proposalDecision: WalletConnectProposalDecision) async throws { record(proposalDecision) }
    func submit(signDecision: WalletConnectSignDecision) async throws { record(signDecision) }
    private func record(_ decision: WalletConnectProposalDecision) {
        lock.lock()
        proposals.append(decision)
        lock.unlock()
    }
    private func record(_ decision: WalletConnectSignDecision) {
        lock.lock()
        signs.append(decision)
        lock.unlock()
    }
}

final class CovJOnWcRouter: WalletConnectCoordinatorRouter {
    var isBusy = false
    var dismissals = 0
    func setRoot(controller _: UIViewController) {}
    func present(controller _: UIViewController) {}
    func dismiss(completion: (() -> Void)?) {
        dismissals += 1
        isBusy = false
        completion?()
    }
}

final class CovJOnWcFlow: DefaultCoordinator, CoordinatorFinishOutput, WalletConnectSigningFlow {
    var finishFlow: (() -> Void)?
    var isSigning = false
    private(set) var starts = 0
    private weak var router: CovJOnWcRouter?
    init(router: CovJOnWcRouter?) { self.router = router }
    override func start() {
        starts += 1
        router?.isBusy = true
    }
}

final class CovJOnCoordinatorFixture {
    let center = NotificationCenter()
    let service = CovJOnWcService()
    let router = CovJOnWcRouter()
    let lockState: ApplicationLockState
    var flows: [CovJOnWcFlow] = []
    let unavailable = CovJOnCoordinatorFixture.pendingNotice()
    let scam = CovJOnCoordinatorFixture.pendingNotice()
    var coordinator: WalletConnectCoordinator!

    static func pendingNotice() -> WalletConnectNoticePresenter {
        WalletConnectNoticePresenter(
            topViewController: { nil },
            isApplicationActive: { true },
            makeViewModel: { locale, _ in WalletConnectNoticePresenter.signingUnavailableViewModel(locale: locale) }
        )
    }

    init() {
        lockState = ApplicationLockState(notificationCenter: center)
        coordinator = WalletConnectCoordinator(
            walletConnect: service,
            router: router,
            lockState: lockState,
            notificationCenter: center,
            isApplicationActive: { true },
            signingUnavailableNotice: unavailable,
            scamNotice: scam,
            makeRequestFlow: { [unowned self] router, _, _, _ in self.makeFlow(router) },
            makeProposalFlow: { [unowned self] router, _, _ in self.makeFlow(router) }
        )
    }

    private func makeFlow(_ router: WalletConnectCoordinatorRouter) -> CovJOnWcFlow {
        let flow = CovJOnWcFlow(router: router as? CovJOnWcRouter)
        flows.append(flow)
        return flow
    }

    static func proposal(id: Int64) -> Session.Proposal {
        Session.Proposal(
            id: id,
            pairingTopic: "covj-pairing-\(id)",
            proposer: AppMetadata(name: "CovJ", description: "", url: "https://app.example.invalid", icons: []),
            requiredNamespaces: [:],
            optionalNamespaces: nil,
            sessionProperties: nil,
            expiryDate: Date(timeIntervalSinceNow: 300)
        )
    }

    static func request(id: Int64, topic: String = "covj-topic") throws -> Request {
        try Request(
            id: id,
            topic: topic,
            method: WalletConnectMethod.ethereumPersonalSign.rawValue,
            params: AnyCodable(["0x00", "0x00"]),
            chainId: XCTUnwrap(Blockchain("eip155:1"))
        )
    }
}

final class CovJOnWalletConnectCoordinatorTests: XCTestCase {
    func testDuplicateProposalIsIgnoredUntilItsFlowFinishes() {
        let fixture = CovJOnCoordinatorFixture()
        let proposal = CovJOnCoordinatorFixture.proposal(id: 1_794_000_000_100_001)
        fixture.coordinator.session(proposal: proposal, verification: .verified)
        fixture.coordinator.session(proposal: proposal, verification: .verified)
        XCTAssertEqual(fixture.flows.count, 1)
        XCTAssertEqual(fixture.flows.first?.starts, 1)

        fixture.flows.first?.finishFlow?()
        XCTAssertEqual(fixture.router.dismissals, 1)
        XCTAssertTrue(fixture.coordinator.childCoordinators.isEmpty)

        fixture.coordinator.session(proposal: proposal, verification: .verified)
        XCTAssertEqual(fixture.flows.count, 2, "A finished proposal can be shown again")
        XCTAssertEqual(fixture.flows.last?.starts, 1)
        XCTAssertTrue(fixture.service.proposalDecisions.isEmpty)
    }

    func testBecomingActiveStartsTheWaitingFlow() throws {
        let fixture = CovJOnCoordinatorFixture()
        fixture.router.isBusy = true
        fixture.coordinator.sign(request: try CovJOnCoordinatorFixture.request(id: 41), session: nil, verification: .verified)
        XCTAssertEqual(fixture.flows.count, 1)
        XCTAssertEqual(fixture.flows.first?.starts, 0, "A busy router keeps the flow waiting")

        fixture.router.isBusy = false
        fixture.coordinator.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))
        XCTAssertEqual(fixture.flows.first?.starts, 1)
    }

    func testUnavailableSigningAndScamsRaisePendingNotices() throws {
        let fixture = CovJOnCoordinatorFixture()
        XCTAssertFalse(fixture.unavailable.isNoticePending)
        XCTAssertFalse(fixture.scam.isNoticePending)
        fixture.coordinator.signingUnavailable(request: try CovJOnCoordinatorFixture.request(id: 7), session: nil)
        fixture.coordinator.blockedScam(origin: "https://scam.example.invalid")
        XCTAssertTrue(fixture.unavailable.isNoticePending)
        XCTAssertTrue(fixture.scam.isNoticePending)
        fixture.coordinator.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))
        XCTAssertTrue(fixture.unavailable.isNoticePending, "Nothing to present on: the notice keeps waiting")
        XCTAssertTrue(fixture.coordinator.childCoordinators.isEmpty)
    }

    func testDefaultCollaboratorsAreBuiltWithoutStartingFlows() {
        let center = NotificationCenter()
        let service = CovJOnWcService()
        let coordinator = WalletConnectCoordinator(
            walletConnect: service,
            router: CovJOnWcRouter(),
            lockState: ApplicationLockState(notificationCenter: center),
            notificationCenter: center
        )
        XCTAssertTrue(service.listener === coordinator)
        coordinator.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))
        XCTAssertTrue(coordinator.childCoordinators.isEmpty)
    }
}

final class CovJOnNoticePresenterTests: XCTestCase {
    func testNoticeIsPresentedOnceAndAFurtherRequestIsCoveredByIt() throws {
        let host = UIViewController()
        let window = try CovJViewFixture.host(host)
        defer {
            host.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        var builtLocales: [Locale] = []
        let notice = WalletConnectNoticePresenter(
            topViewController: { host },
            isApplicationActive: { true },
            makeViewModel: { locale in
                builtLocales.append(locale)
                return WalletConnectNoticePresenter.requestEndedViewModel(locale: locale)
            }
        )
        notice.requestNotice()
        XCTAssertTrue(host.presentedViewController is SheetAletViewController)
        XCTAssertFalse(notice.isNoticePending)
        XCTAssertTrue(notice.isPresentingNotice)
        XCTAssertEqual(builtLocales.count, 1)

        notice.requestNotice(origin: "https://again.example.invalid")
        XCTAssertFalse(notice.isNoticePending)
        XCTAssertEqual(builtLocales.count, 1, "The notice on screen covers the new request")
    }

    func testInactiveAppKeepsTheNoticePending() {
        let notice = WalletConnectNoticePresenter(
            topViewController: { UIViewController() },
            isApplicationActive: { false },
            makeViewModel: { locale in WalletConnectNoticePresenter.signingPausedViewModel(locale: locale) }
        )
        notice.presentPendingNoticeIfPossible()
        XCTAssertFalse(notice.isNoticePending)
        notice.requestNotice()
        XCTAssertTrue(notice.isNoticePending)
        XCTAssertFalse(notice.isPresentingNotice)
    }

    func testRequestEndedTextUsesTheLocale() {
        let locale = CovJFixture.locale
        let model = WalletConnectNoticePresenter.requestEndedViewModel(locale: locale)
        XCTAssertEqual(model.title, R.string.localizable.walletConnectRequestEndedTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.message, R.string.localizable.walletConnectRequestEndedMessage(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.closeAction, R.string.localizable.commonClose(preferredLanguages: locale.rLanguages))
        XCTAssertTrue(model.actions.isEmpty)
        XCTAssertNil(model.icon)
    }
}
