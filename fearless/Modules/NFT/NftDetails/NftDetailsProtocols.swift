typealias NftDetailsModuleCreationResult = (view: NftDetailsViewInput, input: NftDetailsModuleInput)

protocol NftDetailsViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: NftDetailViewModel)
}

protocol NftDetailsViewOutput: AnyObject {
    func didLoad(view: NftDetailsViewInput)
    func didBackButtonTapped()
    func didTapSendButton()
    func didTapShareButton()
    func didTapCopy()
}

protocol NftDetailsInteractorInput: AnyObject {
    func setup(with output: NftDetailsInteractorOutput)
}

protocol NftDetailsInteractorOutput: AnyObject {
    func didReceive(nft: NFT)
    func didReceive(owners: [String])
}

protocol NftDetailsRouterInput: AnyObject, PushDismissable, ApplicationStatusPresentable, SharingPresentable {
    func openSend(nft: NFT, wallet: MetaAccountModel, from view: ControllerBackedProtocol?)
}

protocol NftDetailsModuleInput: AnyObject {}

protocol NftDetailsModuleOutput: AnyObject {}
