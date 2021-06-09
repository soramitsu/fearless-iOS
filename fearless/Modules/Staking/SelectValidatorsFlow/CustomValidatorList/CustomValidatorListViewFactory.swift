import Foundation

struct CustomValidatorListViewFactory {
    static func createView(selectedValidators: [ElectedValidatorInfo]) -> CustomValidatorListViewProtocol? {
        // TODO: FLW-891 add missing parameters: maxTargets, recommendedValidators etc.
        let interactor = CustomValidatorListInteractor()
        let wireframe = CustomValidatorListWireframe()
        let viewModelFactory = CustomValidatorListViewModelFactory()

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            validators: selectedValidators
        )

        let view = CustomValidatorListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
