import Foundation

final class WalletConnectConfirmationCoordinator: DefaultCoordinator, CoordinatorFinishOutput {
    private let router: WalletConnectCoordinatorRouter
    private let inputData: WalletConnectConfirmationInputData

    init(
        router: WalletConnectCoordinatorRouter,
        inputData: WalletConnectConfirmationInputData
    ) {
        self.router = router
        self.inputData = inputData
    }

    // MARK: - CoordinatorFinishOutput

    var finishFlow: (() -> Void)?

    // MARK: - Coordinator

    override func start() {
        presentConfirmation()
    }

    // MARK: - Private methods

    private func presentConfirmation() {
        let module = WalletConnectConfirmationAssembly.configureModule(inputData: inputData)
        guard let controller = module?.view.controller else {
            return
        }
        controller.addOnInteractionDismiss { [weak self] in
            self?.finishFlow?()
        }
        router.present(controller: controller)
    }
}
