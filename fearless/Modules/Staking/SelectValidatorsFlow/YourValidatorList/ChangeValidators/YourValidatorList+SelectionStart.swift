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
            selectedValidatorList: SharedList<SelectedValidatorInfo>,
            maxTargets: Int,
            asset: AssetModel,
            chain: ChainModel,
            selectedAccount: MetaAccountModel
        ) {
            guard let nextView = CustomValidatorListViewFactory.createChangeYourValidatorsView(
                asset: asset,
                chain: chain,
                selectedAccount: selectedAccount,
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
            maxTargets: Int,
            selectedAccount: MetaAccountModel,
            chain: ChainModel,
            asset: AssetModel
        ) {
            guard let nextView = RecommendedValidatorListViewFactory.createChangeYourValidatorsView(
                for: validatorList,
                maxTargets: maxTargets,
                selectedAccount: selectedAccount,
                asset: asset,
                chain: chain,
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
