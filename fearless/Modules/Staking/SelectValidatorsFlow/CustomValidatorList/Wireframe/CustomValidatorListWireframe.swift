import Foundation

class CustomValidatorListWireframe: CustomValidatorListWireframeProtocol {
    func present(
        asset: AssetModel,
        chain: ChainModel,
        validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory.createView(
                asset: asset,
                chain: chain,
                validatorInfo: validatorInfo
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
        filter: CustomValidatorListFilter,
        delegate: ValidatorListFilterDelegate?,
        asset: AssetModel
    ) {
        guard let filterView = ValidatorListFilterViewFactory
            .createView(
                asset: asset,
                with: filter,
                delegate: delegate
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            filterView.controller,
            animated: true
        )
    }

    func presentSearch(
        from view: ControllerBackedProtocol?,
        fullValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?,
        chain: ChainModel,
        asset: AssetModel
    ) {
        guard let searchView = ValidatorSearchViewFactory
            .createView(
                asset: asset,
                chain: chain,
                with: fullValidatorList,
                selectedValidatorList: selectedValidatorList,
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
