import Foundation

final class StoriesPresenter {
    weak var view: StoriesViewProtocol?
    var wireframe: StoriesWireframeProtocol!
    var interactor: StoriesInteractorInputProtocol!

    var selectedStoryIndex = 0

    private var model: StoriesModel?

    init() {
    }

    private func show(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }
}

extension StoriesPresenter: StoriesPresenterProtocol {
    func activateClose() {
        wireframe.close(view: view)
    }

    func activateWeb(slideIndex: Int) {
        guard let urlString = model?.stories[selectedStoryIndex].slides[slideIndex].urlString else { return }

        if let url = URL(string: urlString) {
            show(url)
        }
    }

    func proceedToNextStory() {
        guard let model = self.model else { return }
        guard selectedStoryIndex + 1 < model.stories.count else {
            activateClose()
            return
        }

        selectedStoryIndex += 1
        view?.didRecieve(story: model.stories[selectedStoryIndex])
    }

    func proceedToPreviousStory() {
        guard let model = self.model else { return }
        guard selectedStoryIndex - 1 >= 0 else {
            activateClose()
            return
        }

        selectedStoryIndex -= 1
        view?.didRecieve(story: model.stories[selectedStoryIndex])
    }

    func setup() {
        interactor.setup()
    }
}

extension StoriesPresenter: StoriesInteractorOutputProtocol {
    func didReceive(storiesModel: StoriesModel) {
        model = storiesModel
        view?.didRecieve(story: storiesModel.stories[selectedStoryIndex])
    }
}
