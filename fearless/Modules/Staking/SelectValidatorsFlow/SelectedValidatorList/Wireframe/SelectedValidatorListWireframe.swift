class SelectedValidatorListWireframe: SelectedValidatorListWireframeProtocol {
    func present(_ validatorInfo: ValidatorInfoProtocol, from view: ControllerBackedProtocol?) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory
            .createView(with: validatorInfo) else {
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
        maxTargets _: Int
    ) {}

    func dismiss(_ view: ControllerBackedProtocol?) {
        view?.controller
            .navigationController?
            .popViewController(animated: true)
    }
}
