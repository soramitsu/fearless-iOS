import Foundation
import SoraFoundation

protocol StoriesViewProtocol: ControllerBackedProtocol, Localizable {
    // From Interactor through Presenter to View actions
    // func didReceive(value: Type)
    func didRecieve(story: Story)
}

protocol StoriesPresenterProtocol: class {
    func setup()

    func activateClose()

    func activateWeb()
    // From View to Presenter actions
    // func viewAction()
}

protocol StoriesInteractorInputProtocol: class {
    func setup()
}

protocol StoriesInteractorOutputProtocol: class {
    // From Interactor to Presenter actions
    func didReceive(storiesModel: StoriesModel)
}

protocol StoriesWireframeProtocol: WebPresentable {
    func close(view: StoriesViewProtocol?)
}

protocol StoriesViewFactoryProtocol: class {
    // Setup view
    static func createView(with index: Int) -> StoriesViewProtocol?
}

protocol StoriesProgressViewDataSource {
    func slidesCount() -> Int
}

protocol StoriesProgressViewDelegate {

}
