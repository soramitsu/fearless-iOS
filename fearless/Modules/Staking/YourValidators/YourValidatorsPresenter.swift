import Foundation

final class YourValidatorsPresenter {
    weak var view: YourValidatorsViewProtocol?
    let wireframe: YourValidatorsWireframeProtocol
    let interactor: YourValidatorsInteractorInputProtocol

    init(interactor: YourValidatorsInteractorInputProtocol, wireframe: YourValidatorsWireframeProtocol) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension YourValidatorsPresenter: YourValidatorsPresenterProtocol {
    func setup() {}
}

extension YourValidatorsPresenter: YourValidatorsInteractorOutputProtocol {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>) {}

    func didReceiveElectionStatus(result: Result<ElectionStatus, Error>) {}
}
