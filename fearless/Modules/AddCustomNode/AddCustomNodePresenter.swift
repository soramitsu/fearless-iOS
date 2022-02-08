import Foundation

final class AddCustomNodePresenter {
    weak var view: AddCustomNodeViewProtocol?
    let wireframe: AddCustomNodeWireframeProtocol
    let interactor: AddCustomNodeInteractorInputProtocol
    let viewModelFactory: AddCustomNodeViewModelFactoryProtocol

    init(
        interactor: AddCustomNodeInteractorInputProtocol,
        wireframe: AddCustomNodeWireframeProtocol,
        viewModelFactory: AddCustomNodeViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }
}

extension AddCustomNodePresenter: AddCustomNodePresenterProtocol {
    func setup() {}
    
    func nameTextFieldValueChanged(_ value: String) {
        
    }
    
    func addressTextFieldValueChanged(_ value: String) {
        
    }
}

extension AddCustomNodePresenter: AddCustomNodeInteractorOutputProtocol {}
