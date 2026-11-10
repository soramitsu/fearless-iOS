import Foundation
import FearlessWalletConnect

final class WalletConnectSessionCoordinator: DefaultCoordinator, CoordinatorFinishOutput, WalletConnectSigningFlow {
    private let router: WalletConnectCoordinatorRouter
    private let request: Request
    private let session: Session?
    private let verification: WalletConnectVerification
    private weak var confirmation: WalletConnectConfirmationCoordinator?

    /// True while the confirmation signs: the PIN screen may be up.
    var isSigning: Bool {
        confirmation?.isSigning ?? false
    }

    init(
        router: WalletConnectCoordinatorRouter,
        request: Request,
        session: Session?,
        verification: WalletConnectVerification
    ) {
        self.router = router
        self.request = request
        self.session = session
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
        let module = WalletConnectSessionAssembly.configureModule(
            request: request,
            session: session,
            verification: verification
        ) { [weak self] inputData in
            self?.presentConfirmation(inputData: inputData)
        }
        guard let controller = module?.view.controller else {
            return
        }
        controller.addOnInteractionDismiss { [weak self] in
            self?.finishFlow?()
        }
        router.setRoot(controller: controller)
    }

    private func presentConfirmation(inputData: WalletConnectConfirmationInputData) {
        let coordinator = WalletConnectConfirmationCoordinator(router: router, inputData: inputData)
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.finishFlow?()
        }
        addChildCoordinator(coordinator)
        confirmation = coordinator
        coordinator.start()
    }
}
