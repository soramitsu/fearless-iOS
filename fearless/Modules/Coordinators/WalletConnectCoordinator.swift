import Foundation
import WalletConnectSign
import UIKit

final class WalletConnectCoordinator: DefaultCoordinator {
    // MARK: - Private properties

    private let walletConnect: WalletConnectService = WalletConnectServiceImpl.shared
    private lazy var router: WalletConnectCoordinatorRouter = {
        WalletConnectCoordinatorRouterImpl()
    }()

    override init() {
        super.init()
        walletConnect.set(listener: self)
    }

    // MARK: - private methods

    private func presentNextIfPossible() {
        guard childCoordinators.isNotEmpty, let nextCoordinator = childCoordinators.first else {
            return
        }
        nextCoordinator.start()
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
        addDependency(coordinator)
        if childCoordinators.count == 1 {
            coordinator.start()
        }
    }

    func session(proposal: Session.Proposal) {
        let coordinator = WalletConnectProposalCoordinator(router: router, proposal: proposal)
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeDependency(coordinator)
            self?.presentNextIfPossible()
        }
        addDependency(coordinator)
        if childCoordinators.count == 1 {
            coordinator.start()
        }
    }
}
