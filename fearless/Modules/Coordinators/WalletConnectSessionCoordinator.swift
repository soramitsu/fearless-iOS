import Foundation
import WalletConnectSign

final class WalletConnectSessionCoordinator: DefaultCoordinator, CoordinatorFinishOutput {
    private let router: WalletConnectCoordinatorRouter
    private let variant: ConnectRequestVariant

    init(
        router: WalletConnectCoordinatorRouter,
        variant: ConnectRequestVariant
    ) {
        self.router = router
        self.variant = variant
    }

    // MARK: - CoordinatorFinishOutput

    var finishFlow: (() -> Void)?

    // MARK: - Coordinator

    override func start() {
        runFlow()
    }

    // MARK: - Private methods

    private func runFlow() {
        let module = WalletConnectSessionAssembly.configureModule(variant: variant) { [weak self] inputData in
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
        coordinator.start()
    }
}
