typealias MainNftContainerModuleCreationResult = (view: MainNftContainerViewInput, input: MainNftContainerModuleInput)

protocol MainNftContainerViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [NftListCellModel]?)
}

protocol MainNftContainerViewOutput: AnyObject {
    func didLoad(view: MainNftContainerViewInput)
    func didSelect(collection: NFTCollection)
    func didPullToRefresh()
    func viewAppeared()
}

protocol MainNftContainerInteractorInput: AnyObject {
    func initialSetup()
    func setup(with output: MainNftContainerInteractorOutput)
    func fetchData()
}

protocol MainNftContainerInteractorOutput: AnyObject {
    func didReceive(collections: [NFTCollection])
}

protocol MainNftContainerRouterInput: AnyObject {
    func showCollection(
        _ collection: NFTCollection,
        wallet: MetaAccountModel,
        address: String,
        from view: ControllerBackedProtocol?
    )
}

protocol MainNftContainerModuleInput: AnyObject {}

protocol MainNftContainerModuleOutput: AnyObject {}
