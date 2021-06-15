import Foundation
import SoraFoundation

struct CustomValidatorListViewFactory {
    static func createView(
        electedValidators: [ElectedValidatorInfo],
        recommendedValidators: [ElectedValidatorInfo],
        maxTargets: Int
    ) -> CustomValidatorListViewProtocol? {
        let interactor = CustomValidatorListInteractor()
        let wireframe = CustomValidatorListWireframe()
        let viewModelFactory = CustomValidatorListViewModelFactory()

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            electedValidators: electedValidators,
            recommendedValidators: recommendedValidators,
            maxTargets: maxTargets
        )

        let view = CustomValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: maxTargets
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
