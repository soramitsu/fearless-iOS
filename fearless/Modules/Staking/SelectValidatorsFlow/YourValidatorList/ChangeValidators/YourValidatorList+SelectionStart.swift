import Foundation
import SSFModels

extension YourValidatorList {
    final class SelectionStartWireframe: SelectValidatorsStartWireframe {
        override func proceedToCustomList(
            from view: ControllerBackedProtocol?,
            flow: CustomValidatorListFlow,
            chainAsset: ChainAsset,
            wallet: MetaAccountModel
        ) {
            guard let nextView = CustomValidatorListViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
                flow: flow
            ) else { return }

            view?.controller.navigationController?.pushViewController(
                nextView.controller,
                animated: true
            )
        }

        override func proceedToRecommendedList(
            from view: SelectValidatorsStartViewProtocol?,
            flow: RecommendedValidatorListFlow,
            wallet: MetaAccountModel,
            chainAsset: ChainAsset
        ) {
            guard let nextView = RecommendedValidatorListViewFactory.createView(
                flow: flow,
                chainAsset: chainAsset,
                wallet: wallet
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
