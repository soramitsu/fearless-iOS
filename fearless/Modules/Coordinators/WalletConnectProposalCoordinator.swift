import Foundation
import WalletConnectSign

final class WalletConnectProposalCoordinator: DefaultCoordinator, CoordinatorFinishOutput {
    private let router: WalletConnectCoordinatorRouter
    private let proposal: Session.Proposal

    init(
        router: WalletConnectCoordinatorRouter,
        proposal: Session.Proposal
    ) {
        self.router = router
        self.proposal = proposal
    }

    // MARK: - CoordinatorFinishOutput

    var finishFlow: (() -> Void)?

    // MARK: - Coordinator

    override func start() {
        runFlow()
    }

    // MARK: - Private methods

    private func runFlow() {
        let module = WalletConnectProposalAssembly.configureModule(status: .proposal(proposal))
        guard let controller = module?.view.controller else {
            return
        }
        controller.addOnInteractionDismiss { [weak self] in
            self?.finishFlow?()
        }
        router.setRoot(controller: controller)
    }
}
