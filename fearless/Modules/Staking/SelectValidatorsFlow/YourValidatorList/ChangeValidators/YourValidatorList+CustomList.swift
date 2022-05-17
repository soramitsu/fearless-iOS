extension YourValidatorList {
    final class CustomListWireframe: CustomValidatorListWireframe {
        private let state: ExistingBonding

        init(state: ExistingBonding) {
            self.state = state
        }

        override func proceed(
            from view: ControllerBackedProtocol?,
            validatorList: [SelectedValidatorInfo],
            maxTargets: Int,
            delegate: SelectedValidatorListDelegate,
            chain: ChainModel,
            asset: AssetModel,
            selectedAccount: MetaAccountModel
        ) {
            guard let nextView = SelectedValidatorListViewFactory.createChangeYourValidatorsView(
                for: validatorList,
                maxTargets: maxTargets,
                chain: chain,
                asset: asset,
                selectedAccount: selectedAccount,
                delegate: delegate,
                with: state
            )
            else { return }

            view?.controller.navigationController?.pushViewController(
                nextView.controller,
                animated: true
            )
        }
    }
}
