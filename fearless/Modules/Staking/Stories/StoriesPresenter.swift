import Foundation

final class StoriesPresenter {
    weak var view: StoriesViewProtocol?
    var wireframe: StoriesWireframeProtocol!
    var interactor: StoriesInteractorInputProtocol!

    private var viewModelFactory: StoriesViewModelFactoryProtocol?
    private var selectedStoryIndex = 0
    private var selectedSlideIndex = 0

    private var model: StoriesModel?

    init(
        selectedStoryIndex: Int,
        viewModelFactory: StoriesViewModelFactoryProtocol
    ) {
        self.selectedStoryIndex = selectedStoryIndex
        self.viewModelFactory = viewModelFactory
    }

    private func show(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }

    private func advanceStoriesBy(_ shift: Int, startingFrom slide: StaringIndex = .first) {
        guard let model = self.model else { return }
        guard selectedStoryIndex + shift < model.stories.count,
              selectedStoryIndex + shift >= 0
        else {
            activateClose()
            return
        }

        selectedStoryIndex += shift
        selectedSlideIndex = slide.index

        guard let factory = viewModelFactory else { return }
        let viewModel = factory.createStoryViewModel(from: model.stories[selectedStoryIndex])
        view?.didRecieve(viewModel: viewModel, startingFrom: slide)
    }
}

extension StoriesPresenter: StoriesPresenterProtocol {
    func activateClose() {
        wireframe.close(view: view)
    }

    func activateWeb() {
        guard let urlString = model?
            .stories[selectedStoryIndex]
            .slides[selectedSlideIndex].urlString else { return }

        if let url = URL(string: urlString) {
            show(url)
        }
    }

    func proceedToNextStory() {
        advanceStoriesBy(1)
    }

    func proceedToPreviousStory(startingFrom index: StaringIndex = .first) {
        advanceStoriesBy(-1, startingFrom: index)
    }

    func proceedToNextSlide() {
        guard let model = self.model else { return }
        guard selectedSlideIndex + 1 < model.stories[selectedStoryIndex].slides.count
        else {
            proceedToNextStory()
            return
        }

        selectedSlideIndex += 1
        view?.didRecieve(newSlideIndex: selectedSlideIndex)
    }

    func proceedToPreviousSlide() {
        guard selectedSlideIndex - 1 >= 0
        else {
            guard let model = self.model else { return }
            guard selectedStoryIndex > 0 else {
                proceedToPreviousStory()
                return
            }

            proceedToPreviousStory(startingFrom: .last(array: model.stories[selectedStoryIndex - 1].slides))
            return
        }

        selectedSlideIndex -= 1
        view?.didRecieve(newSlideIndex: selectedSlideIndex)
    }

    func setup() {
        interactor.setup()
    }
}

extension StoriesPresenter: StoriesInteractorOutputProtocol {
    func didReceive(storiesModel: StoriesModel) {
        selectedSlideIndex = 0
        model = storiesModel

        guard let factory = viewModelFactory else { return }
        let viewModel = factory.createStoryViewModel(from: storiesModel.stories[selectedStoryIndex])
        view?.didRecieve(viewModel: viewModel, startingFrom: .first)
    }
}
