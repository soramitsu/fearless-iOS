import Foundation
import SoraFoundation
import FearlessWalletConnect
import UIKit

final class WalletConnectCoordinator: DefaultCoordinator {
    typealias FlowCoordinator = DefaultCoordinator & CoordinatorFinishOutput

    // MARK: - Private properties

    private let walletConnect: WalletConnectService
    private let router: WalletConnectCoordinatorRouter
    private let lockState: ApplicationLockState
    private let notificationCenter: NotificationCenter
    private let isApplicationActive: () -> Bool
    private let makeRequestFlow: (
        WalletConnectCoordinatorRouter,
        Request,
        Session?,
        WalletConnectVerification
    ) -> FlowCoordinator
    private let makeProposalFlow: (
        WalletConnectCoordinatorRouter,
        Session.Proposal,
        WalletConnectVerification
    ) -> FlowCoordinator
    private let signingUnavailableNotice: WalletConnectNoticePresenter
    private let scamNotice: WalletConnectNoticePresenter
    private let signingPausedNotice: WalletConnectNoticePresenter
    private let pairingFailedNotice: WalletConnectNoticePresenter
    private var lockObserver: NSObjectProtocol?

    /// Requests already queued or on screen. The SDK sends the oldest pending request
    /// again whenever another one arrives, so a request is queued only once.
    private var queuedRequestIds: Set<String> = []

    private lazy var applicationHandler: ApplicationHandler = {
        ApplicationHandler()
    }()

    init(
        walletConnect: WalletConnectService = WalletConnectServiceImpl.shared,
        router: WalletConnectCoordinatorRouter = WalletConnectCoordinatorRouterImpl(),
        lockState: ApplicationLockState = .shared,
        notificationCenter: NotificationCenter = .default,
        isApplicationActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active },
        signingUnavailableNotice: WalletConnectNoticePresenter = WalletConnectNoticePresenter { locale in
            WalletConnectNoticePresenter.signingUnavailableViewModel(locale: locale)
        },
        scamNotice: WalletConnectNoticePresenter = WalletConnectNoticePresenter.scamBlocked(),
        signingPausedNotice: WalletConnectNoticePresenter = WalletConnectNoticePresenter { locale in
            WalletConnectNoticePresenter.signingPausedViewModel(locale: locale)
        },
        pairingFailedNotice: WalletConnectNoticePresenter = WalletConnectNoticePresenter.pairingFailed(),
        makeRequestFlow: @escaping (
            WalletConnectCoordinatorRouter,
            Request,
            Session?,
            WalletConnectVerification
        ) -> FlowCoordinator = {
            WalletConnectSessionCoordinator(router: $0, request: $1, session: $2, verification: $3)
        },
        makeProposalFlow: @escaping (
            WalletConnectCoordinatorRouter,
            Session.Proposal,
            WalletConnectVerification
        ) -> FlowCoordinator = {
            WalletConnectProposalCoordinator(router: $0, proposal: $1, verification: $2)
        }
    ) {
        self.walletConnect = walletConnect
        self.router = router
        self.lockState = lockState
        self.notificationCenter = notificationCenter
        self.isApplicationActive = isApplicationActive
        self.signingUnavailableNotice = signingUnavailableNotice
        self.scamNotice = scamNotice
        self.signingPausedNotice = signingPausedNotice
        self.pairingFailedNotice = pairingFailedNotice
        self.makeRequestFlow = makeRequestFlow
        self.makeProposalFlow = makeProposalFlow
        super.init()
        walletConnect.set(listener: self)
        applicationHandler.delegate = self
        lockObserver = notificationCenter.addObserver(
            forName: ApplicationLockState.didChangeNotification,
            object: lockState,
            queue: .main
        ) { [weak self] _ in
            self?.presentNextIfPossible()
            self?.presentPendingNotices()
        }
    }

    deinit {
        if let lockObserver = lockObserver {
            notificationCenter.removeObserver(lockObserver)
        }
    }

    // MARK: - private methods

    /// Starts the oldest waiting flow once the app is active and unlocked, and nothing
    /// else is on screen. While the PIN screen locks the app, flows wait in the queue.
    private func presentPendingNotices() {
        signingUnavailableNotice.presentPendingNoticeIfPossible()
        scamNotice.presentPendingNoticeIfPossible()
        signingPausedNotice.presentPendingNoticeIfPossible()
        pairingFailedNotice.presentPendingNoticeIfPossible()
    }

    private func presentNextIfPossible() {
        guard
            isApplicationActive(),
            !lockState.isLocked,
            !router.isBusy,
            let nextCoordinator = childCoordinators.first
        else {
            return
        }
        nextCoordinator.start()
    }

    private func enqueue(_ coordinator: FlowCoordinator, onFinish: (() -> Void)? = nil) {
        var flow = coordinator
        flow.finishFlow = { [weak self, weak coordinator] in
            onFinish?()
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        addChildCoordinator(flow)
        presentNextIfPossible()
    }
}

// MARK: - WalletConnectServiceDelegate

extension WalletConnectCoordinator: WalletConnectServiceDelegate {
    func sign(request: Request, session: Session?, verification: WalletConnectVerification) {
        let requestId = request.id.string
        guard queuedRequestIds.insert(requestId).inserted else {
            return
        }

        enqueue(makeRequestFlow(router, request, session, verification)) { [weak self] in
            self?.queuedRequestIds.remove(requestId)
        }
    }

    func session(proposal: Session.Proposal, verification: WalletConnectVerification) {
        enqueue(makeProposalFlow(router, proposal, verification))
    }

    func signingUnavailable(request _: Request, session _: Session?) {
        signingUnavailableNotice.requestNotice()
    }

    func blockedScam(origin: String) {
        scamNotice.requestNotice(origin: origin)
    }

    func signingPaused(request _: Request, session _: Session?) {
        signingPausedNotice.requestNotice()
    }

    func pairingFailed(error: Error) {
        pairingFailedNotice.requestNotice(origin: WalletConnectNoticePresenter.pairingFailureMessage(
            for: error,
            locale: LocalizationManager.shared.selectedLocale
        ))
    }
}

// MARK: - ApplicationHandlerDelegate

extension WalletConnectCoordinator: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        presentNextIfPossible()
        presentPendingNotices()
    }
}

/// Tells the user that dApp requests were declined, for example because WalletConnect
/// signing is unavailable (`WalletConnectSigningPolicy`) or WalletConnect Verify flags
/// the app as a scam. Requests that arrive together, or while the app is in the
/// background or locked, share one notice.
final class WalletConnectNoticePresenter {
    private let topViewController: () -> UIViewController?
    private let isApplicationActive: () -> Bool
    private let makeViewModel: (Locale, String?) -> SheetAlertPresentableViewModel
    private weak var noticeController: UIViewController?
    private var origin: String?
    private(set) var isNoticePending = false

    init(
        topViewController: @escaping () -> UIViewController? = { UIApplication.topViewController() },
        isApplicationActive: @escaping () -> Bool = {
            UIApplication.shared.applicationState == .active && !ApplicationLockState.shared.isLocked
        },
        makeViewModel: @escaping (Locale, String?) -> SheetAlertPresentableViewModel
    ) {
        self.topViewController = topViewController
        self.isApplicationActive = isApplicationActive
        self.makeViewModel = makeViewModel
    }

    convenience init(
        topViewController: @escaping () -> UIViewController? = { UIApplication.topViewController() },
        isApplicationActive: @escaping () -> Bool = {
            UIApplication.shared.applicationState == .active && !ApplicationLockState.shared.isLocked
        },
        makeViewModel: @escaping (Locale) -> SheetAlertPresentableViewModel
    ) {
        self.init(
            topViewController: topViewController,
            isApplicationActive: isApplicationActive,
            makeViewModel: { locale, _ in makeViewModel(locale) }
        )
    }

    var isPresentingNotice: Bool {
        noticeController?.presentingViewController != nil
    }

    /// `origin` names the app the notice is about; the latest one is shown.
    func requestNotice(origin: String? = nil) {
        self.origin = origin ?? self.origin
        isNoticePending = true
        presentPendingNoticeIfPossible()
    }

    func presentPendingNoticeIfPossible() {
        guard isNoticePending else {
            return
        }

        // A notice already on screen covers this request as well.
        guard !isPresentingNotice else {
            isNoticePending = false
            return
        }

        guard isApplicationActive(), let presenter = topViewController() else {
            return
        }

        let controller = SheetAletViewController(
            viewModel: makeViewModel(LocalizationManager.shared.selectedLocale, origin)
        )
        controller.modalPresentationStyle = .custom
        controller.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        presenter.present(controller, animated: true)

        // UIKit refuses the presentation when the presenter is already presenting
        // or mid-transition; keep the notice pending until the next activation.
        guard controller.presentingViewController != nil else {
            return
        }

        noticeController = controller
        isNoticePending = false
    }

    static func signingUnavailableViewModel(locale: Locale) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        return SheetAlertPresentableViewModel(
            title: R.string.localizable.walletConnectSigningUnavailableTitle(preferredLanguages: languages),
            message: R.string.localizable.walletConnectSigningUnavailableMessage(preferredLanguages: languages),
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            icon: nil
        )
    }

    static func signingPausedViewModel(locale: Locale) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        return SheetAlertPresentableViewModel(
            title: R.string.localizable.walletConnectSigningPausedTitle(preferredLanguages: languages),
            message: R.string.localizable.walletConnectSigningPausedMessage(preferredLanguages: languages),
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            icon: nil
        )
    }

    /// A pairing link failed. The notice's text comes from `pairingFailureMessage(for:locale:)`.
    static func pairingFailed() -> WalletConnectNoticePresenter {
        WalletConnectNoticePresenter(makeViewModel: { locale, message in
            let languages = locale.rLanguages
            return SheetAlertPresentableViewModel(
                title: R.string.localizable.walletConnectLinkFailedTitle(preferredLanguages: languages),
                message: message ?? R.string.localizable.walletConnectLinkFailedMessage(preferredLanguages: languages),
                actions: [],
                closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                icon: nil
            )
        })
    }

    /// What to tell the user about a pairing link that failed: the link's own problem when the service named one
    /// (an old-version or malformed link), that it expired, or that a new one is needed.
    static func pairingFailureMessage(for error: Error, locale: Locale) -> String {
        let languages = locale.rLanguages
        if let content = error as? ConvenienceContentError {
            return content.message
        }
        if case WalletConnectClient.ClientError.pairingExpired = error {
            return R.string.localizable.walletConnectLinkExpiredMessage(preferredLanguages: languages)
        }
        return R.string.localizable.walletConnectLinkFailedMessage(preferredLanguages: languages)
    }

    static func scamBlocked() -> WalletConnectNoticePresenter {
        WalletConnectNoticePresenter(makeViewModel: { locale, origin in
            scamBlockedViewModel(origin: origin ?? "", locale: locale)
        })
    }

    static func scamBlockedViewModel(origin: String, locale: Locale) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        return SheetAlertPresentableViewModel(
            title: R.string.localizable.walletConnectScamBlockedTitle(preferredLanguages: languages),
            message: R.string.localizable.walletConnectScamBlockedMessage(origin, preferredLanguages: languages),
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            icon: nil
        )
    }
}
