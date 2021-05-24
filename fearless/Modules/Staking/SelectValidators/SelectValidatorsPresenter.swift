import Foundation

final class SelectValidatorsPresenter {
    weak var view: SelectValidatorsViewProtocol?
    let wireframe: SelectValidatorsWireframeProtocol
    let interactor: SelectValidatorsInteractorInputProtocol

    init(
        interactor: SelectValidatorsInteractorInputProtocol,
        wireframe: SelectValidatorsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SelectValidatorsPresenter: SelectValidatorsPresenterProtocol {
    func setup() {}
}

extension SelectValidatorsPresenter: SelectValidatorsInteractorOutputProtocol {}
