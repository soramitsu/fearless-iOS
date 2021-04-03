import Foundation
import SoraFoundation

protocol StoriesViewProtocol: ControllerBackedProtocol, Localizable {
    func didRecieve(
        viewModel: [SlideViewModel],
        startingFrom slide: StaringIndex
    )
    func didRecieve(newSlideIndex index: Int)
}

protocol StoriesPresenterProtocol: AnyObject {
    func setup()

    func activateClose()
    func activateWeb()
    func proceedToNextStory()
    func proceedToPreviousStory(startingFrom slide: StaringIndex)
    func proceedToNextSlide()
    func proceedToPreviousSlide()
}

protocol StoriesInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StoriesInteractorOutputProtocol: AnyObject {
    func didReceive(storiesModel: StoriesModel)
}

protocol StoriesWireframeProtocol: WebPresentable {
    func close(view: StoriesViewProtocol?)
}

protocol StoriesViewFactoryProtocol: AnyObject {
    static func createView(with index: Int) -> StoriesViewProtocol?
}
