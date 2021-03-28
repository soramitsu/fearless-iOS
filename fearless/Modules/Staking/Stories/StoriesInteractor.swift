import Foundation

final class StoriesInteractor {
    weak var presenter: StoriesInteractorOutputProtocol!

    private var storiesModel: StoriesModel?
    // Provide data to Presenter
    // func provideDataToPresenter() {
    //     presenter.didReceive(data: data)
    // }
}

extension StoriesInteractor: StoriesInteractorInputProtocol {
    func setup() {
        let model = StoriesFactory.createModel()
        presenter.didReceive(storiesModel: model)
    }
}
