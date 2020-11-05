import SoraFoundation
import IrohaCrypto

protocol AccountInfoViewProtocol: ControllerBackedProtocol {
    func set(usernameViewModel: InputViewModelProtocol)
    func set(address: String)
    func set(networkType: SNAddressType)
}

protocol AccountInfoPresenterProtocol: class {
    func setup()
    func activateClose()
    func activateExport()
    func activateCopyAddress()
    func save(username: String)
}

protocol AccountInfoInteractorInputProtocol: class {
    func setup(address: String)
    func save(username: String, address: String)
    func requestExportOptions(address: String)
}

protocol AccountInfoInteractorOutputProtocol: class {
    func didReceive(exportOptions: [ExportOption])
    func didReceive(accountItem: ManagedAccountItem)
    func didSave(username: String)
    func didReceive(error: Error)
}

protocol AccountInfoWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting {
    func close(view: AccountInfoViewProtocol?)
    func showExport(for address: String,
                    options: [ExportOption],
                    locale: Locale?,
                    from view: AccountInfoViewProtocol?)
}

protocol AccountInfoViewFactoryProtocol: class {
    static func createView(address: String) -> AccountInfoViewProtocol?
}
