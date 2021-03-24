import Foundation
import SoraFoundation

protocol StoriesViewProtocol: ControllerBackedProtocol, Localizable {
    // From Interactor through Presenter to View actions
    // func didReceive(value: Type)
}

protocol StoriesPresenterProtocol: class {
    func setup()

    // From View to Presenter actions
    // func viewAction()
}

protocol StoriesInteractorInputProtocol: class {
    func setup()
}

protocol StoriesInteractorOutputProtocol: class {
    // From Interactor to Presenter actions
    // func didReceive(value: Type)
    // func didReceive(valueError: Error)
}

protocol StoriesWireframeProtocol {
    // Navigation and alert functions
    // func showNextScreen()
}

protocol StoriesViewFactoryProtocol: class {
    // Setup view
    static func createView() -> StoriesViewProtocol?
}
