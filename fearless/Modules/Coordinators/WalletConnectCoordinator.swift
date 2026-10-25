import Foundation
import SoraFoundation
import WalletConnectSign
import UIKit

final class WalletConnectCoordinator: DefaultCoordinator {
    // MARK: - Private properties

    private let walletConnect: WalletConnectService = WalletConnectServiceImpl.shared
    private lazy var router: WalletConnectCoordinatorRouter = {
        WalletConnectCoordinatorRouterImpl()
    }()

    private lazy var applicationHandler: ApplicationHandler = {
        ApplicationHandler()
    }()

    private let signingUnavailableNotice: WalletConnectSigningUnavailableNoticePresenter

    init(signingUnavailableNotice: WalletConnectSigningUnavailableNoticePresenter = .init()) {
        self.signingUnavailableNotice = signingUnavailableNotice
        super.init()
        walletConnect.set(listener: self)
        applicationHandler.delegate = self
    }

    // MARK: - private methods

    private func presentNextIfPossible() {
        guard childCoordinators.isNotEmpty, let nextCoordinator = childCoordinators.first, !router.isBusy else {
            return
        }
        nextCoordinator.start()
    }

    private func startIfPossible(with coordinator: DefaultCoordinator) {
        let applicationState = UIApplication.shared.applicationState
        switch applicationState {
        case .active:
            addChildCoordinator(coordinator)
            guard !router.isBusy else {
                return
            }
            coordinator.start()

        case .background, .inactive:
            addChildCoordinator(coordinator)
        @unknown default:
            preconditionFailure()
        }
    }
}

// MARK: - WalletConnectServiceDelegate

extension WalletConnectCoordinator: WalletConnectServiceDelegate {
    func sign(request: Request, session: Session?) {
        let coordinator = WalletConnectSessionCoordinator(router: router, request: request, session: session)
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        startIfPossible(with: coordinator)
    }

    func session(proposal: Session.Proposal) {
        let coordinator = WalletConnectProposalCoordinator(router: router, proposal: proposal)
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        startIfPossible(with: coordinator)
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
/// the app is in the background, share one notice.
final class WalletConnectSigningUnavailableNoticePresenter {
    private let topViewController: () -> UIViewController?
    private let isApplicationActive: () -> Bool
    private weak var noticeController: UIViewController?
    private(set) var isNoticePending = false

    init(
        topViewController: @escaping () -> UIViewController? = { UIApplication.topViewController() },
        isApplicationActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }
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
