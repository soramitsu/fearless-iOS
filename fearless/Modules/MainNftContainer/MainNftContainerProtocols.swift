typealias MainNftContainerModuleCreationResult = (view: MainNftContainerViewInput, input: MainNftContainerModuleInput)

protocol MainNftContainerViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [NftListCellModel])
    func didReceive(history: [NFTHistoryObject])
}

protocol MainNftContainerViewOutput: AnyObject {
    func didLoad(view: MainNftContainerViewInput)
}

protocol MainNftContainerInteractorInput: AnyObject {
    func setup(with output: MainNftContainerInteractorOutput)
}

protocol MainNftContainerInteractorOutput: AnyObject {
    func didReceive(history: [NFTHistoryObject])
    func didReceive(nfts: [NFT])
}

protocol MainNftContainerRouterInput: AnyObject {}

protocol MainNftContainerModuleInput: AnyObject {}

protocol MainNftContainerModuleOutput: AnyObject {}
