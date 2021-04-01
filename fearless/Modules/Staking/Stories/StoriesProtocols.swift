import Foundation
import SoraFoundation

protocol StoriesViewProtocol: ControllerBackedProtocol, Localizable {
    func didRecieve(viewModel: [SlideViewModel],
                    startingFrom slide: StaringIndex)
    func didRecieve(newSlideIndex index: Int)
}

protocol StoriesPresenterProtocol: class {
    func setup()

    func activateClose()
    func activateWeb()
    func proceedToNextStory()
    func proceedToPreviousStory(startingFrom slide: StaringIndex)
    func proceedToNextSlide()
    func proceedToPreviousSlide()
}

protocol StoriesInteractorInputProtocol: class {
    func setup()
}

protocol StoriesInteractorOutputProtocol: class {
    func didReceive(storiesModel: StoriesModel)
}

protocol StoriesWireframeProtocol: WebPresentable {
    func close(view: StoriesViewProtocol?)
}

protocol StoriesViewFactoryProtocol: class {
    static func createView(with index: Int) -> StoriesViewProtocol?
}
