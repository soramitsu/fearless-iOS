import Foundation

final class YourValidatorListWireframe: YourValidatorListWireframeProtocol {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        asset: AssetModel,
        chain: ChainModel,
        from view: YourValidatorListViewProtocol?
    ) {
        guard
            let nextView = ValidatorInfoViewFactory.createView(
                asset: asset,
                chain: chain,
                validatorInfo: validatorInfo
            ) else {
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
        guard let nextView = SelectValidatorsStartViewFactory.createChangeYourValidatorsView(
            selectedAccount: selectedAccount,
            asset: asset,
            chain: chain,
            state: existingBonding
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
