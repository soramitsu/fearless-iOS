import Foundation
import SoraFoundation

struct SelectedValidatorListViewFactory {
    static func createView(
        selectedValidators: [ElectedValidatorInfo],
        maxTargets: Int
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = SelectedValidatorListWireframe()
        let viewModelFactory = SelectedValidatorListViewModelFactory()

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedValidators: selectedValidators,
            maxTargets: maxTargets
        )

        let view = SelectedValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: maxTargets,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
