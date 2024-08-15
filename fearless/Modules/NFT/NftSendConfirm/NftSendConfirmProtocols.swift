import SSFModels

typealias NftSendConfirmModuleCreationResult = (view: NftSendConfirmViewInput, input: NftSendConfirmModuleInput)

protocol NftSendConfirmViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(receiverViewModel: AccountViewModel?)
    func didReceive(senderViewModel: AccountViewModel?)
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(nftViewModel: NftSendConfirmViewModel)
}

protocol NftSendConfirmViewOutput: AnyObject {
    func didLoad(view: NftSendConfirmViewInput)
    func didBackButtonTapped()
    func didConfirmButtonTapped()
}

protocol NftSendConfirmInteractorInput: AnyObject {
    func setup(with output: NftSendConfirmInteractorOutput)
    func estimateFee(for nft: NFT, address: String?)
    func submitExtrinsic(nft: NFT, receiverAddress: String)
}

protocol NftSendConfirmInteractorOutput: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didTransfer(result: Result<String, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

protocol NftSendConfirmRouterInput: AnyObject, PushDismissable, ErrorPresentable, BaseErrorPresentable, ModalAlertPresenting, SheetAlertPresentable {
    func complete(
        on view: ControllerBackedProtocol,
        title: String,
        chainAsset: ChainAsset?
    )
}

protocol NftSendConfirmModuleInput: AnyObject {}

protocol NftSendConfirmModuleOutput: AnyObject {}
