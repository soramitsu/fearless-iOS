class SelectedValidatorListWireframe: SelectedValidatorListWireframeProtocol {
    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
                flow: flow
            )
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func proceed(
        from view: SelectedValidatorListViewProtocol?,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard let confirmView = SelectValidatorsConfirmViewFactory
            .createView(
                chainAsset: chainAsset,
                flow: flow,
                wallet: wallet
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

    func dismiss(_ view: ControllerBackedProtocol?) {
        view?.controller
            .navigationController?
            .popViewController(animated: true)
    }
}
