import Foundation
import FearlessWalletConnect

final class WalletConnectProposalCoordinator: DefaultCoordinator, CoordinatorFinishOutput {
    private let router: WalletConnectCoordinatorRouter
    private let proposal: Session.Proposal
    private let verification: WalletConnectVerification

    init(
        router: WalletConnectCoordinatorRouter,
        proposal: Session.Proposal,
        verification: WalletConnectVerification
    ) {
        self.router = router
        self.proposal = proposal
        self.verification = verification
    }

    // MARK: - CoordinatorFinishOutput

    var finishFlow: (() -> Void)?

    // MARK: - Coordinator

    override func start() {
        runFlow()
    }

    // MARK: - Private methods

    private func runFlow() {
        let module = WalletConnectProposalAssembly.configureModule(
            status: .proposal(proposal),
            verification: verification
        )
        guard let controller = module?.view.controller else {
            return
        }
        controller.addOnInteractionDismiss { [weak self] in
            self?.finishFlow?()
        }
        router.setRoot(controller: controller)
    }
}
