import Foundation

final class StoriesInteractor {
    weak var presenter: StoriesInteractorOutputProtocol!

    private var storiesModel: StoriesModel?
}

extension StoriesInteractor: StoriesInteractorInputProtocol {
    func setup() {
        let model = StoriesFactory.createModel()
        presenter.didReceive(storiesModel: model)
    }
}
