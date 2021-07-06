import Foundation

extension YourValidatorList {
    final class SelectionStartWireframe: SelectValidatorsStartWireframe {
        private let state: ExistingBonding

        init(state: ExistingBonding) {
            self.state = state
        }

        override func proceedToCustomList(
            from view: ControllerBackedProtocol?,
            validatorList: [SelectedValidatorInfo],
            recommendedValidatorList: [SelectedValidatorInfo],
            maxTargets: Int
        ) {
            guard let nextView = CustomValidatorListViewFactory.createChangeYourValidatorsView(
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
            guard let nextView = RecommendedValidatorListViewFactory.createChangeYourValidatorsView(
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
}
