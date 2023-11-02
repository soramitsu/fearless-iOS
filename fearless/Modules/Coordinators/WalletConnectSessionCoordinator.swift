import Foundation
import WalletConnectSign

final class WalletConnectSessionCoordinator: DefaultCoordinator, CoordinatorFinishOutput {
    private let router: WalletConnectCoordinatorRouter
    private let request: Request
    private let session: Session?

    init(
        router: WalletConnectCoordinatorRouter,
        request: Request,
        session: Session?
    ) {
        self.router = router
        self.request = request
        self.session = session
    }

    // MARK: - CoordinatorFinishOutput

    var finishFlow: (() -> Void)?

    // MARK: - Coordinator

    override func start() {
        runFlow()
    }

    // MARK: - Private methods

    private func runFlow() {
        let module = WalletConnectSessionAssembly.configureModule(request: request, session: session) { [weak self] inputData in
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
            self?.removeDependency(coordinator)
            self?.finishFlow?()
        }
        addDependency(coordinator)
        coordinator.start()
    }
}
