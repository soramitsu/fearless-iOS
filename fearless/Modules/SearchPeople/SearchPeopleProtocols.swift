import CommonWallet
protocol SearchPeopleViewProtocol: ControllerBackedProtocol {
    func didReceive(state: SearchPeopleViewState)
}

protocol SearchPeoplePresenterProtocol: AnyObject {
    func setup()
    func searchTextDidChanged(_ text: String)
}

protocol SearchPeopleInteractorInputProtocol: AnyObject {
    func performSearch(query: String)
}

protocol SearchPeopleInteractorOutputProtocol: AnyObject {
    func didReceive(searchResult: Result<[SearchData]?, Error>)
}

protocol SearchPeopleWireframeProtocol: AnyObject {}
