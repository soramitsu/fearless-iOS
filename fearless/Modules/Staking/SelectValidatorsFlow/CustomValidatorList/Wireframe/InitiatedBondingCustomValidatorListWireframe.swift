final class InitiatedBondingCustomValidatorListWireframe: CustomValidatorListWireframe {
    let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceed(
        from view: ControllerBackedProtocol?,
        validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate
    ) {
        guard let nextView = SelectedValidatorListViewFactory
            .createInitiatedBondingView(
                for: validators,
                maxTargets: maxTargets,
                delegate: delegate,
                with: state
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
