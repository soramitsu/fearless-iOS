class SelectedValidatorListWireframe: SelectedValidatorListWireframeProtocol {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        asset: AssetModel,
        chain: ChainModel,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory
            .createView(
                asset: asset,
                chain: chain,
                validatorInfo: validatorInfo
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func proceed(
        from _: SelectedValidatorListViewProtocol?,
        targets _: [SelectedValidatorInfo],
        maxTargets _: Int,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel
    ) {}

    func dismiss(_ view: ControllerBackedProtocol?) {
        view?.controller
            .navigationController?
            .popViewController(animated: true)
    }
}
