import BigInt

protocol WalletSendConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(state: WalletSendConfirmViewState)
}

protocol WalletSendConfirmPresenterProtocol: AnyObject {
    func setup()
    func didTapConfirmButton()
    func didTapBackButton()
    func didTapScamWarningButton()
}

protocol WalletSendConfirmInteractorInputProtocol: AnyObject {
    var dependencyContainer: SendDepencyContainer { get }

    func setup()
    func submitExtrinsic(for transferAmount: BigUInt, tip: BigUInt?, receiverAddress: String)
    func estimateFee(for amount: BigUInt, tip: BigUInt?)
    func getUtilityAsset(for chainAsset: ChainAsset?) -> ChainAsset?
}

protocol WalletSendConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId?)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)

    func didTransfer(result: Result<String, Error>)
}

protocol WalletSendConfirmWireframeProtocol:
    ErrorPresentable,
    BaseErrorPresentable,
    ModalAlertPresenting,
    SheetAlertPresentable {
    func close(view: ControllerBackedProtocol?)
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    )
}
