
protocol WalletTransactionDetailsViewProtocol: ControllerBackedProtocol {
    func didReceiveState(_ state: WalletTransactionDetailsViewState)
}

protocol WalletTransactionDetailsPresenterProtocol: AnyObject {
    func setup()
    func didTapCloseButton()
    func didTapReceiverOrValidatorView()
    func didTapSenderView()
    func didTapExtrinsicView()
}

protocol WalletTransactionDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletTransactionDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveTransaction(_ transaction: AssetTransactionData)
}

protocol WalletTransactionDetailsWireframeProtocol: AnyObject, AddressOptionsPresentable, ExtrinsicOptionsPresentable, TextCopyPresentable {
    func close(view: ControllerBackedProtocol?)
}
