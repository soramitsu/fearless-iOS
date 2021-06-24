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

    func presentSearch(from view: ControllerBackedProtocol?) {
        guard
            let searchView = ValidatorSearchViewFactory
            .createView() else { return }

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
