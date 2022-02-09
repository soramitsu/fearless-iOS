final class InitiatedBondingSelectedValidatorListWireframe: SelectedValidatorListWireframe {
    let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceed(
        from view: SelectedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        let nomination = PreparedNomination(
            bonding: state,
            targets: targets,
            maxTargets: maxTargets
        )

        guard let confirmView = SelectValidatorsConfirmViewFactory
            .createInitiatedBondingView(
                selectedAccount: selectedAccount,
                asset: asset,
                chain: chain,
                for: nomination
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
