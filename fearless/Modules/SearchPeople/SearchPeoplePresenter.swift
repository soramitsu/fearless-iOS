import Foundation
import CommonWallet

final class SearchPeoplePresenter {
    weak var view: SearchPeopleViewProtocol?
    let wireframe: SearchPeopleWireframeProtocol
    let interactor: SearchPeopleInteractorInputProtocol

    init(
        interactor: SearchPeopleInteractorInputProtocol,
        wireframe: SearchPeopleWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SearchPeoplePresenter: SearchPeoplePresenterProtocol {
    func setup() {}
}

extension SearchPeoplePresenter: SearchPeopleInteractorOutputProtocol {
    func didReceive(searchResult _: Result<[SearchData]?, Error>) {}
}
