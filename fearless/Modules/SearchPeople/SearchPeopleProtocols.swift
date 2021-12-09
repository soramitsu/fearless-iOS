import CommonWallet
protocol SearchPeopleViewProtocol: ControllerBackedProtocol {
    func didReceive(state: SearchPeopleViewState)
    func didReceive(title: String?)
}

protocol SearchPeoplePresenterProtocol: AnyObject {
    func setup()
    func searchTextDidChanged(_ text: String)
    func didTapBackButton()
}

protocol SearchPeopleInteractorInputProtocol: AnyObject {
    func performSearch(query: String)
}

protocol SearchPeopleInteractorOutputProtocol: AnyObject {
    func didReceive(searchResult: Result<[SearchData]?, Error>)
}

protocol SearchPeopleWireframeProtocol: AnyObject {
    func close(_ view: ControllerBackedProtocol?)
}
