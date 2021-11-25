protocol ChainAccountBalanceListViewProtocol: AnyObject {
    func didReceive(state: ChainAccountBalanceListViewState)
}

protocol ChainAccountBalanceListPresenterProtocol: AnyObject {
    func setup()
}

protocol ChainAccountBalanceListInteractorInputProtocol: AnyObject {}

protocol ChainAccountBalanceListInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
}

protocol ChainAccountBalanceListWireframeProtocol: AnyObject {}
