import Foundation

final class ControllerAccountPresenter {
    weak var view: ControllerAccountViewProtocol?
    var wireframe: ControllerAccountWireframeProtocol!
    var interactor: ControllerAccountInteractorInputProtocol!
}

extension ControllerAccountPresenter: ControllerAccountPresenterProtocol {
    func setup() {}
}

extension ControllerAccountPresenter: ControllerAccountInteractorOutputProtocol {}
