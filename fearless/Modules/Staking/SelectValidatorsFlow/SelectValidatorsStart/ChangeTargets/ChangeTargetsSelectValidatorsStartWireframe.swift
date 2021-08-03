import Foundation

final class ChangeTargetsSelectValidatorsStartWireframe: SelectValidatorsStartWireframe {
    private let state: ExistingBonding

    init(state: ExistingBonding) {
        self.state = state
    }

    override func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int
    ) {
        guard let nextView = CustomValidatorListViewFactory
            .createChangeTargetsView(
                for: validatorList,
                with: recommendedValidatorList,
                selectedValidatorList: selectedValidatorList,
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
        guard let nextView = RecommendedValidatorListViewFactory.createChangeTargetsView(
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
