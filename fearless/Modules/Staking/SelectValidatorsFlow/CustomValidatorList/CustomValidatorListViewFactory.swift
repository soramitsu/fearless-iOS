import Foundation

struct CustomValidatorListViewFactory {
    static func createView(
        electedValidators: [ElectedValidatorInfo],
        maxTargets: Int
    ) -> CustomValidatorListViewProtocol? {
        // TODO: FLW-891 add missing parameters: maxTargets, recommendedValidators etc.
        let interactor = CustomValidatorListInteractor()
        let wireframe = CustomValidatorListWireframe()
        let viewModelFactory = CustomValidatorListViewModelFactory()

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            electedValidators: electedValidators,
            maxTargets: maxTargets
        )

        let view = CustomValidatorListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
