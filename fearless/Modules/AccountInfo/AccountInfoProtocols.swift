import SoraFoundation
import IrohaCrypto

protocol AccountInfoViewProtocol: ControllerBackedProtocol {
    func set(usernameViewModel: InputViewModelProtocol)
    func set(address: String)
    func set(networkType: Chain)
    func set(cryptoType: CryptoType)
}

protocol AccountInfoPresenterProtocol: class {
    func setup()
    func activateClose()
    func activateExport()
    func activateAddressAction()
    func finalizeUsername()
}

protocol AccountInfoInteractorInputProtocol: class {
    func setup(address: String)
    func save(username: String, address: String)
    func requestExportOptions(accountItem: ManagedAccountItem)
    func flushPendingUsername()
}

protocol AccountInfoInteractorOutputProtocol: class {
    func didReceive(exportOptions: [ExportOption])
    func didReceive(accountItem: ManagedAccountItem)
    func didSave(username: String)
    func didReceive(error: Error)
}

protocol AccountInfoWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting, WebPresentable {
    func close(view: AccountInfoViewProtocol?)

    func showExport(for address: String,
                    options: [ExportOption],
                    locale: Locale?,
                    from view: AccountInfoViewProtocol?)

    func presentAddressOptions(_ address: String,
                               chain: Chain,
                               locale: Locale,
                               copyClosure: @escaping  () -> Void,
                               from view: AccountInfoViewProtocol?)
}

protocol AccountInfoViewFactoryProtocol: class {
    static func createView(address: String) -> AccountInfoViewProtocol?
}
