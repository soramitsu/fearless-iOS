import CommonWallet
protocol SearchPeopleViewProtocol: AnyObject {}

protocol SearchPeoplePresenterProtocol: AnyObject {
    func setup()
}

protocol SearchPeopleInteractorInputProtocol: AnyObject {
    func performSearch(query: String)
}

protocol SearchPeopleInteractorOutputProtocol: AnyObject {
    func didReceive(searchResult: Result<[SearchData]?, Error>)
}

protocol SearchPeopleWireframeProtocol: AnyObject {}
