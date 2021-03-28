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

    func activateWeb() {
        let urlString = "https://wiki.polkadot.network/docs/en/learn-staking"

        if let url = URL(string: urlString) {
            show(url)
        }
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
