typealias MainNftContainerModuleCreationResult = (view: MainNftContainerViewInput, input: MainNftContainerModuleInput)

protocol MainNftContainerViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [NftListCellModel])
    func didReceive(history: [NFTHistoryObject])
}

protocol MainNftContainerViewOutput: AnyObject {
    func didLoad(view: MainNftContainerViewInput)
    func didSelect(collection: NFTCollection)
}

protocol MainNftContainerInteractorInput: AnyObject {
    func setup(with output: MainNftContainerInteractorOutput)
}

protocol MainNftContainerInteractorOutput: AnyObject {
    func didReceive(history: [NFTHistoryObject])
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
