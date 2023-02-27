import SoraUI

final class StakingBondMoreConfirmationWireframe: StakingBondMoreConfirmationWireframeProtocol,
    ModalAlertPresenting, AllDonePresentable {
    func complete(
        from view: StakingBondMoreConfirmationViewProtocol,
        chainAsset: ChainAsset,
        extrinsicHash: String
    ) {
        let presenter = view.controller.navigationController?.presentingViewController
        let navigationController = view.controller.navigationController

        let allDoneController = AllDoneAssembly.configureModule(chainAsset: chainAsset, hashString: extrinsicHash)?.view.controller
        allDoneController?.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        allDoneController?.modalTransitioningFactory = factory

        navigationController?.dismiss(animated: true, completion: {
            if let presenter = presenter as? ControllerBackedProtocol, let allDoneController = allDoneController {
                presenter.controller.present(allDoneController, animated: true)
            }
        })
    }
}
