extension YourValidatorList {
    final class RecommendationWireframe: RecommendedValidatorListWireframe {
        private let state: ExistingBonding

        init(state: ExistingBonding) {
            self.state = state
        }

        override func proceed(
            from view: RecommendedValidatorListViewProtocol?,
            flow: SelectValidatorsConfirmFlow,
            wallet: MetaAccountModel,
            chainAsset: ChainAsset
        ) {
            guard let confirmView = SelectValidatorsConfirmViewFactory
                .createChangeYourValidatorsView(
                    wallet: wallet,
                    chainAsset: chainAsset,
                    flow: flow
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                confirmView.controller,
                animated: true
            )
        }
    }
}
