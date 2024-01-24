typealias NftCollectionModuleCreationResult = (view: NftCollectionViewInput, input: NftCollectionModuleInput)

protocol NftCollectionViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: NftCollectionViewModel)
}

protocol NftCollectionViewOutput: AnyObject {
    func didLoad(view: NftCollectionViewInput)
    func viewAppeared()
    func didBackButtonTapped()
    func didSelect(nft: NFT, type: NftType)
    func didTapActionButton(nft: NFT, type: NftType)
    func loadNext()
}

protocol NftCollectionInteractorInput: AnyObject {
    func initialSetup()
    func setup(with output: NftCollectionInteractorOutput)
    func loadNext()
}

protocol NftCollectionInteractorOutput: AnyObject {
    func didReceive(collection: NFTCollection)
}

protocol NftCollectionRouterInput: AnyObject, PresentDismissable, SharingPresentable {
    func openNftDetails(nft: NFT, type: NftType, wallet: MetaAccountModel, address: String, from view: ControllerBackedProtocol?)
    func openSend(nft: NFT, wallet: MetaAccountModel, from view: ControllerBackedProtocol?)
}

protocol NftCollectionModuleInput: AnyObject {}

protocol NftCollectionModuleOutput: AnyObject {}
