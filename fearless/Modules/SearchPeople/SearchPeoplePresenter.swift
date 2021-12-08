import Foundation
import CommonWallet

final class SearchPeoplePresenter {
    weak var view: SearchPeopleViewProtocol?
    let wireframe: SearchPeopleWireframeProtocol
    let interactor: SearchPeopleInteractorInputProtocol
    let viewModelFactory: SearchPeopleViewModelFactoryProtocol

    private var searchResult: Result<[SearchData]?, Error>?

    init(
        interactor: SearchPeopleInteractorInputProtocol,
        wireframe: SearchPeopleWireframeProtocol,
        viewModelFactory: SearchPeopleViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func provideViewModel() {
        switch searchResult {
        case let .success(searchData):
            guard let searchData = searchData, !searchData.isEmpty else {
                view?.didReceive(state: .empty)
                return
            }

            let viewModel = viewModelFactory.buildSearchPeopleViewModel(results: searchData)
            view?.didReceive(state: .loaded(viewModel))
        case .failure:
            view?.didReceive(state: .error)
        case .none:
            view?.didReceive(state: .empty)
        }
    }
}

extension SearchPeoplePresenter: SearchPeoplePresenterProtocol {
    func searchTextDidChanged(_ text: String) {
        interactor.performSearch(query: text)
    }

    func setup() {}
}

extension SearchPeoplePresenter: SearchPeopleInteractorOutputProtocol {
    func didReceive(searchResult: Result<[SearchData]?, Error>) {
        self.searchResult = searchResult
        provideViewModel()
    }
}
