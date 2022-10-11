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
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let searchView = ValidatorSearchViewFactory
            .createView(
                chainAsset: chainAsset,
                flow: flow,
                wallet: wallet
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            searchView.controller,
            animated: true
        )
    }

    func proceed(
        from view: ControllerBackedProtocol?,
        flow: SelectedValidatorListFlow,
        delegate: SelectedValidatorListDelegate,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let listView = SelectedValidatorListViewFactory.createView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            listView.controller,
            animated: true
        )
    }

    func confirm(from view: ControllerBackedProtocol?, flow: SelectValidatorsConfirmFlow, chainAsset: ChainAsset, wallet: MetaAccountModel) {
        guard let confirmView = SelectValidatorsConfirmViewFactory
            .createView(
                chainAsset: chainAsset,
                flow: flow,
                wallet: wallet
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
