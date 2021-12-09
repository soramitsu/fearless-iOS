import Foundation
import CommonWallet
import SoraFoundation

final class SearchPeoplePresenter {
    weak var view: SearchPeopleViewProtocol?
    let wireframe: SearchPeopleWireframeProtocol
    let interactor: SearchPeopleInteractorInputProtocol
    let viewModelFactory: SearchPeopleViewModelFactoryProtocol
    let asset: AssetModel

    private var searchResult: Result<[SearchData]?, Error>?

    init(
        interactor: SearchPeopleInteractorInputProtocol,
        wireframe: SearchPeopleWireframeProtocol,
        viewModelFactory: SearchPeopleViewModelFactoryProtocol,
        asset: AssetModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.asset = asset
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
    func didTapBackButton() {
        wireframe.close(view)
    }

    func searchTextDidChanged(_ text: String) {
        interactor.performSearch(query: text)
    }

    func setup() {
        view?.didReceive(title: R.string.localizable.walletSendNavigationTitle(asset.symbol, preferredLanguages: selectedLocale.rLanguages))
    }
}

extension SearchPeoplePresenter: SearchPeopleInteractorOutputProtocol {
    func didReceive(searchResult: Result<[SearchData]?, Error>) {
        self.searchResult = searchResult
        provideViewModel()
    }
}

extension SearchPeoplePresenter: Localizable {
    func applyLocalization() {}
}
