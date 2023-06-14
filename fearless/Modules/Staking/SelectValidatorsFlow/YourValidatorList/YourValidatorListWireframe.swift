import Foundation
import SSFModels

final class YourValidatorListWireframe: YourValidatorListWireframeProtocol {
    func proceedToSelectValidatorsStart(
        from view: YourValidatorListViewProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: SelectValidatorsStartFlow
    ) {
        guard let nextView = SelectValidatorsStartViewFactory.createView(
            wallet: wallet,
            chainAsset: chainAsset,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: YourValidatorListViewProtocol?
    ) {
        guard
            let nextView = ValidatorInfoViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
                flow: flow
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
