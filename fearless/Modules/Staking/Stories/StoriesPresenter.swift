import Foundation

final class StoriesPresenter {
    weak var view: StoriesViewProtocol?
    var wireframe: StoriesWireframeProtocol!
    var interactor: StoriesInteractorInputProtocol!

    init() {
    }
}

extension StoriesPresenter: StoriesPresenterProtocol {
    func setup() {
//        <#code#>

        interactor.setup()
    }
}

extension StoriesPresenter: StoriesInteractorOutputProtocol {

}

