final class InitBondingCustomValidatorListWireframe: CustomValidatorListWireframe {
    let state: InitiatedBonding

    init(state: InitiatedBonding) {
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
        guard let nextView = SelectedValidatorListViewFactory.createInitiatedBondingView(
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
