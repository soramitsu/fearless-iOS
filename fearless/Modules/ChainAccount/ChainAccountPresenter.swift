import Foundation

final class ChainAccountPresenter {
    weak var view: ChainAccountViewProtocol?
    let wireframe: ChainAccountWireframeProtocol
    let interactor: ChainAccountInteractorInputProtocol

    init(
        interactor: ChainAccountInteractorInputProtocol,
        wireframe: ChainAccountWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ChainAccountPresenter: ChainAccountPresenterProtocol {
    func setup() {}
}

extension ChainAccountPresenter: ChainAccountInteractorOutputProtocol {}
