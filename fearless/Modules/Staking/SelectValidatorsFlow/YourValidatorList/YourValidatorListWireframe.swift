import Foundation

final class YourValidatorListWireframe: YourValidatorListWireframeProtocol {
    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: YourValidatorListViewProtocol?
    ) {
        guard
            let nextView = ValidatorInfoViewFactory.createView(chainAsset: chainAsset, wallet: wallet, flow: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    func proceedToSelectValidatorsStart(
        from view: YourValidatorListViewProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel,
        existingBonding: ExistingBonding
    ) {
        guard let nextView = SelectValidatorsStartViewFactory.createView(
            wallet: selectedAccount,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            flow: .relaychainExisting(state: existingBonding)
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
