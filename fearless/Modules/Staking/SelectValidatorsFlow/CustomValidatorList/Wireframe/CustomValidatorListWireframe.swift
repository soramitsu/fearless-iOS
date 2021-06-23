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

    func presentFilters() {
        // TODO: https://soramitsu.atlassian.net/browse/FLW-894
    }

    func presentSearch() {
        // TODO: https://soramitsu.atlassian.net/browse/FLW-893
    }

    func proceed(
        from _: CustomValidatorListViewProtocol?,
        validators _: [ElectedValidatorInfo],
        maxTargets _: Int,
        delegate _: SelectedValidatorListDelegate
    ) {}
}
