final class SelectedValidatorListWireframe: SelectedValidatorListWireframeProtocol {
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

    func proceed(from _: SelectedValidatorListViewProtocol?, targets _: [SelectedValidatorInfo], maxTargets _: Int) {
        #warning("Not implemented")
        /*
         final class ChangeTargetsRecommendationWireframe: RecommendedValidatorListWireframe {
             let state: ExistingBonding

             init(state: ExistingBonding) {
                 self.state = state
             }

             override func proceed(
                 from view: RecommendedValidatorListViewProtocol?,
                 targets: [SelectedValidatorInfo],
                 maxTargets: Int
             ) {
                 let nomination = PreparedNomination(
                     bonding: state,
                     targets: targets,
                     maxTargets: maxTargets
                 )

                 guard let confirmView = SelectValidatorsConfirmViewFactory.createChangeTargetsView(for: nomination) else {
                     return
                 }

                 view?.controller.navigationController?.pushViewController(
                     confirmView.controller,
                     animated: true
                 )
             }
         }
         */
    }
}
