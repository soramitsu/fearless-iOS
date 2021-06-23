extension YourValidatorList {
    final class CustomListWireframe: CustomValidatorListWireframe {
        private let state: ExistingBonding

        init(state: ExistingBonding) {
            self.state = state
        }

        override func proceed(
            from view: CustomValidatorListViewProtocol?,
            validators: [ElectedValidatorInfo],
            maxTargets: Int,
            delegate: SelectedValidatorListDelegate
        ) {
            guard let nextView = SelectedValidatorListViewFactory
                .createChangeYourValidatorsView(
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
}
