import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: AccountImportSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol)
    func setPassword(viewModel: InputViewModelProtocol)
    func setSelectedCrypto(model: TitleWithSubtitleViewModel)
    func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)
    func setDerivationPath(viewModel: InputViewModelProtocol)

    func didCompleteSourceTypeSelection()
    func didCompleteCryptoTypeSelection()
    func didCompleteAddressTypeSelection()

    func didValidateDerivationPath(_ status: FieldStatus)
}

protocol AccountImportPresenterProtocol: class {
    func setup()
    func selectSourceType()
    func selectCryptoType()
    func selectAddressType()
    func activateQrScan()
    func validateDerivationPath()
    func proceed()
}

protocol AccountImportInteractorInputProtocol: class {
    func setup()
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest)
    func importAccountWithSeed(request: AccountImportSeedRequest)
    func importAccountWithKeystore(request: AccountImportKeystoreRequest)
    func deriveUsernameFromKeystore(_ keystore: String)
}

protocol AccountImportInteractorOutputProtocol: class {
    func didReceiveAccountImport(metadata: AccountImportMetadata)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Error)
    func didDeriveKeystore(username: String)
    func didSuggestKeystore(text: String, username: String?)
}

protocol AccountImportWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(from view: AccountImportViewProtocol?)

    func presentSourceTypeSelection(from view: AccountImportViewProtocol?,
                                    availableSources: [AccountImportSource],
                                    selectedSource: AccountImportSource,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?)

    func presentCryptoTypeSelection(from view: AccountImportViewProtocol?,
                                    availableTypes: [CryptoType],
                                    selectedType: CryptoType,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?)

    func presentAddressTypeSelection(from view: AccountImportViewProtocol?,
                                     availableTypes: [SNAddressType],
                                     selectedType: SNAddressType,
                                     delegate: ModalPickerViewControllerDelegate?,
                                     context: AnyObject?)
}

protocol AccountImportViewFactoryProtocol: class {
	static func createViewForOnboarding() -> AccountImportViewProtocol?
    static func createViewForAdding() -> AccountImportViewProtocol?
    static func createViewForConnection(item: ConnectionItem) -> AccountImportViewProtocol?
}
