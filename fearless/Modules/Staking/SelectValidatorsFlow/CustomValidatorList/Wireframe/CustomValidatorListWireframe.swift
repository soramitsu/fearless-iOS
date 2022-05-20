import Foundation

class CustomValidatorListWireframe: CustomValidatorListWireframeProtocol {
    func present(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: ValidatorInfoFlow,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
                flow: flow
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func presentFilters(
        from view: ControllerBackedProtocol?,
        flow: ValidatorListFilterFlow,
        delegate: ValidatorListFilterDelegate?,
        asset: AssetModel
    ) {
        guard let filterView = ValidatorListFilterViewFactory
            .createView(
                asset: asset,
                flow: flow,
                delegate: delegate
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            filterView.controller,
            animated: true
        )
    }

    func presentSearch(
        from view: ControllerBackedProtocol?,
        flow: ValidatorSearchFlow,
        delegate: ValidatorSearchDelegate?,
        chainAsset: ChainAsset
    ) {
        guard let searchView = ValidatorSearchViewFactory
            .createView(
                chainAsset: chainAsset,
                flow: flow,
                delegate: delegate
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            searchView.controller,
            animated: true
        )
    }

    func proceed(
        from _: ControllerBackedProtocol?,
        validatorList _: [SelectedValidatorInfo],
        maxTargets _: Int,
        delegate _: SelectedValidatorListDelegate,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel
    ) {}
}
