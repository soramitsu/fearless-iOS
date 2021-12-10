protocol ChainAccountViewProtocol: ControllerBackedProtocol {
    func didReceiveState(_ state: ChainAccountViewState)
}

protocol ChainAccountPresenterProtocol: AnyObject {
    func setup()
    func didTapBackButton()
}

protocol ChainAccountInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ChainAccountInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId)
}

protocol ChainAccountWireframeProtocol: AnyObject {
    func close(view: ControllerBackedProtocol?)
}
