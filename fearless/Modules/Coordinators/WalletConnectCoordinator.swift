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

    override init() {
        super.init()
        walletConnect.set(listener: self)
        applicationHandler.delegate = self
    }

    // MARK: - private methods

    private func presentNextIfPossible() {
        guard childCoordinators.isNotEmpty, let nextCoordinator = childCoordinators.first else {
            return
        }
        nextCoordinator.start()
    }

    private func startIfPossible(with coordinator: DefaultCoordinator) {
        let applicationState = UIApplication.shared.applicationState
        switch applicationState {
        case .active:
            addDependency(coordinator)
            if childCoordinators.count == 1 {
                coordinator.start()
            }
        case .background, .inactive:
            addDependency(coordinator)
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
            self?.removeDependency(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        startIfPossible(with: coordinator)
    }

    func session(proposal: Session.Proposal) {
        let coordinator = WalletConnectProposalCoordinator(router: router, proposal: proposal)
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeDependency(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        startIfPossible(with: coordinator)
    }
}

// MARK: - ApplicationHandlerDelegate

extension WalletConnectCoordinator: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        presentNextIfPossible()
    }
}
