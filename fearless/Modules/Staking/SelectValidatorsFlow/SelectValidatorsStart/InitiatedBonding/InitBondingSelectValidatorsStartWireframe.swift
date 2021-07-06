import Foundation

final class InitBondingSelectValidatorsStartWireframe: SelectValidatorsStartWireframe {
    private let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int
    ) {
        guard let nextView = CustomValidatorListViewFactory
            .createInitiatedBondingView(
                for: validatorList,
                with: recommendedValidatorList,
                maxTargets: maxTargets,
                with: state
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    override func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int
    ) {
        guard let nextView = RecommendedValidatorListViewFactory.createInitiatedBondingView(
            for: validatorList,
            maxTargets: maxTargets,
            with: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
