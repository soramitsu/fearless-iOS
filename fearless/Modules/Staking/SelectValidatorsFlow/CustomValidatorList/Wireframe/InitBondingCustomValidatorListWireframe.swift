final class InitBondingCustomValidatorListWireframe: CustomValidatorListWireframe {
    let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceed(
        from view: ControllerBackedProtocol?,
        flow: SelectedValidatorListFlow,
        delegate: SelectedValidatorListDelegate,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let nextView = SelectedValidatorListViewFactory.createInitiatedBondingView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
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
