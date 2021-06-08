import Foundation

struct SelectValidatorsViewFactory {
    static func createView(selectedValidators: [ElectedValidatorInfo]) -> SelectValidatorsViewProtocol? {
        let interactor = SelectValidatorsInteractor()
        let wireframe = SelectValidatorsWireframe()
        let viewModelFactory = SelectValidatorsViewModelFactory()

        let presenter = SelectValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            validators: selectedValidators
        )

        let view = SelectValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
