import Foundation
import JSONRPC
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
    private let makeRequestFlow: (WalletConnectCoordinatorRouter, Request, Session?) -> FlowCoordinator
    private let makeProposalFlow: (WalletConnectCoordinatorRouter, Session.Proposal) -> FlowCoordinator
    private let signingUnavailableNotice: WalletConnectSigningUnavailableNoticePresenter
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
        signingUnavailableNotice: WalletConnectSigningUnavailableNoticePresenter = .init(),
        makeRequestFlow: @escaping (WalletConnectCoordinatorRouter, Request, Session?) -> FlowCoordinator = {
            WalletConnectSessionCoordinator(router: $0, request: $1, session: $2)
        },
        makeProposalFlow: @escaping (WalletConnectCoordinatorRouter, Session.Proposal) -> FlowCoordinator = {
            WalletConnectProposalCoordinator(router: $0, proposal: $1)
        }
    ) {
        self.walletConnect = walletConnect
        self.router = router
        self.lockState = lockState
        self.notificationCenter = notificationCenter
        self.isApplicationActive = isApplicationActive
        self.signingUnavailableNotice = signingUnavailableNotice
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
            self?.signingUnavailableNotice.presentPendingNoticeIfPossible()
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
    func sign(request: Request, session: Session?) {
        let requestId = request.id.string
        guard queuedRequestIds.insert(requestId).inserted else {
            return
        }

        enqueue(makeRequestFlow(router, request, session)) { [weak self] in
            self?.queuedRequestIds.remove(requestId)
        }
    }

    func session(proposal: Session.Proposal) {
        enqueue(makeProposalFlow(router, proposal))
    }

    func signingUnavailable(request _: Request, session _: Session?) {
        signingUnavailableNotice.requestNotice()
    }
}

// MARK: - ApplicationHandlerDelegate

extension WalletConnectCoordinator: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        presentNextIfPossible()
        signingUnavailableNotice.presentPendingNoticeIfPossible()
    }
}

/// Tells the user that a dApp request was declined because WalletConnect signing is
/// unavailable (`WalletConnectSigningPolicy`). Requests that arrive together, or while
/// the app is in the background or locked, share one notice.
final class WalletConnectSigningUnavailableNoticePresenter {
    private let topViewController: () -> UIViewController?
    private let isApplicationActive: () -> Bool
    private weak var noticeController: UIViewController?
    private(set) var isNoticePending = false

    init(
        topViewController: @escaping () -> UIViewController? = { UIApplication.topViewController() },
        isApplicationActive: @escaping () -> Bool = {
            UIApplication.shared.applicationState == .active && !ApplicationLockState.shared.isLocked
        }
    ) {
        self.topViewController = topViewController
        self.isApplicationActive = isApplicationActive
    }

    var isPresentingNotice: Bool {
        noticeController?.presentingViewController != nil
    }

    func requestNotice() {
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
            viewModel: Self.makeViewModel(locale: LocalizationManager.shared.selectedLocale)
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

    static func makeViewModel(locale: Locale) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        return SheetAlertPresentableViewModel(
            title: R.string.localizable.walletConnectSigningUnavailableTitle(preferredLanguages: languages),
            message: R.string.localizable.walletConnectSigningUnavailableMessage(preferredLanguages: languages),
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            icon: nil
        )
    }
}
