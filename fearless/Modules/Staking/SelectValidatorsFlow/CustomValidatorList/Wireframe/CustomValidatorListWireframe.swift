import Foundation

class CustomValidatorListWireframe: CustomValidatorListWireframeProtocol {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory
            .createView(with: validatorInfo) else {
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
        delegate: ValidatorListFilterDelegate?
    ) {
        guard let filterView = ValidatorListFilterViewFactory
            .createView(
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
        allValidators: [ElectedValidatorInfo],
        selectedValidators: [ElectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    ) {
        guard let searchView = ValidatorSearchViewFactory
            .createView(
                with: allValidators,
                selectedValidators: selectedValidators,
                delegate: delegate
            ) else { return }

        view?.controller.navigationController?.pushViewController(
            searchView.controller,
            animated: true
        )
    }

    func proceed(
        from _: ControllerBackedProtocol?,
        validators _: [ElectedValidatorInfo],
        maxTargets _: Int,
        delegate _: SelectedValidatorListDelegate
    ) {}
}
