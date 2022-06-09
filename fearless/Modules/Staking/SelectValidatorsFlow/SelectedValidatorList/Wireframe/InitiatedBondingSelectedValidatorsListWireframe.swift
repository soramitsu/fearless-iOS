final class InitiatedBondingSelectedValidatorListWireframe: SelectedValidatorListWireframe {
    override func proceed(
        from view: SelectedValidatorListViewProtocol?,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard let confirmView = SelectValidatorsConfirmViewFactory
            .createInitiatedBondingView(
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
