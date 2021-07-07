import SoraFoundation

protocol SignerConfirmViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveCall(viewModel: SignerConfirmCallViewModel)
    func didReceiveFee(viewModel: SignerConfirmFeeViewModel)
}

protocol SignerConfirmPresenterProtocol: AnyObject {
    func setup()
    func presentAccountOptions()
    func confirm()
}

protocol SignerConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func confirm()
    func refreshFee()
}

protocol SignerConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didExtractRequest(result: Result<SignerConfirmation, Error>)
    func didReceivePrice(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveSubmition(result: Result<Void, Error>)
}

protocol SignerConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting,
    BaseErrorPresentable, AddressOptionsPresentable {
    func complete(on view: SignerConfirmViewProtocol?)
}
