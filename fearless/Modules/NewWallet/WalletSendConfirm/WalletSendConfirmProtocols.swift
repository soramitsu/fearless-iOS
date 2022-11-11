import BigInt

typealias WalletTransferFinishBlock = () -> Void

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
    func setup()
    func submitExtrinsic(for transferAmount: BigUInt, tip: BigUInt?, receiverAddress: String)
    func estimateFee(for amount: BigUInt, tip: BigUInt?)
}

protocol WalletSendConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
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
        title: String
    )
}
