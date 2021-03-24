import Foundation

final class StoriesInteractor {
    weak var presenter: StoriesInteractorOutputProtocol!

    // Provide data to Presenter
    // func provideDataToPresenter() {
    //     presenter.didReceive(data: data)
    // }
}

extension StoriesInteractor: StoriesInteractorInputProtocol {
    func setup() {
        // Interactor setup
        // Subscriptions
        // Data provision
    }
}
