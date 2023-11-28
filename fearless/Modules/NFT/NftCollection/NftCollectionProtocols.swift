typealias NftCollectionModuleCreationResult = (view: NftCollectionViewInput, input: NftCollectionModuleInput)

protocol NftCollectionViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: NftCollectionViewModel)
}

protocol NftCollectionViewOutput: AnyObject {
    func didLoad(view: NftCollectionViewInput)
    func didBackButtonTapped()
    func didSelect(nft: NFT, type: NftType)
}

protocol NftCollectionInteractorInput: AnyObject {
    func setup(with output: NftCollectionInteractorOutput)
}

protocol NftCollectionInteractorOutput: AnyObject {
    func didReceive(collection: NFTCollection)
}

protocol NftCollectionRouterInput: AnyObject, PresentDismissable {
    func openNftDetails(nft: NFT, type: NftType, wallet: MetaAccountModel, address: String, from view: ControllerBackedProtocol?)
}

protocol NftCollectionModuleInput: AnyObject {}

protocol NftCollectionModuleOutput: AnyObject {}
