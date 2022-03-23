protocol ManageAssetsViewProtocol: AnyObject {}

protocol ManageAssetsPresenterProtocol: AnyObject {
    func setup()
}

protocol ManageAssetsInteractorInputProtocol: AnyObject {}

protocol ManageAssetsInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
}

protocol ManageAssetsWireframeProtocol: AnyObject {}
