import Foundation

final class StoriesInteractor {
    weak var presenter: StoriesInteractorOutputProtocol!

    private let storiesModel: StoriesModel

    init(model: StoriesModel) {
        self.storiesModel = model
    }
}

extension StoriesInteractor: StoriesInteractorInputProtocol {
    func setup() {
        presenter.didReceive(storiesModel: storiesModel)
    }
}
