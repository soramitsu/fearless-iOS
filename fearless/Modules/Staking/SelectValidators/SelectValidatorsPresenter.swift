import Foundation

final class SelectValidatorsPresenter {
    weak var view: SelectValidatorsViewProtocol?
    let wireframe: SelectValidatorsWireframeProtocol
    let interactor: SelectValidatorsInteractorInputProtocol
    let viewModelFactory: SelectValidatorsViewModelFactory
    private let selectedValidators: [ElectedValidatorInfo]

    init(
        interactor: SelectValidatorsInteractorInputProtocol,
        wireframe: SelectValidatorsWireframeProtocol,
        viewModelFactory: SelectValidatorsViewModelFactory,
        validators: [ElectedValidatorInfo]
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        selectedValidators = validators
    }
}

extension SelectValidatorsPresenter: SelectValidatorsPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViewModel(validators: selectedValidators)
        view?.reload(with: viewModel)
    }
}

extension SelectValidatorsPresenter: SelectValidatorsInteractorOutputProtocol {}
