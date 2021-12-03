import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: AccountImportSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol)
    func setPassword(viewModel: InputViewModelProtocol)
    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)
    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol)
    func setEthereumDerivationPath(viewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)

    func didCompleteSourceTypeSelection()
    func didCompleteCryptoTypeSelection()

    func didValidateSubstrateDerivationPath(_ status: FieldStatus)
    func didValidateEthereumDerivationPath(_ status: FieldStatus)
}

protocol AccountImportPresenterProtocol: AnyObject {
    func setup()
    func selectSourceType()
    func selectCryptoType()
    func activateUpload()
    func validateSubstrateDerivationPath()
    func validateEthereumDerivationPath()
    func proceed()
}

protocol AccountImportInteractorInputProtocol: AnyObject {
    func setup()
    func importAccountWithMnemonic(request: MetaAccountImportMnemonicRequest)
    func importAccountWithSeed(request: MetaAccountImportSeedRequest)
    func importAccountWithKeystore(request: MetaAccountImportKeystoreRequest)
    func deriveMetadataFromKeystore(_ keystore: String)
}

protocol AccountImportInteractorOutputProtocol: AnyObject {
    func didReceiveAccountImport(metadata: MetaAccountImportMetadata)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Error)
    func didSuggestKeystore(text: String, preferredInfo: MetaAccountImportPreferredInfo?)
}

protocol AccountImportWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(from view: AccountImportViewProtocol?)

    func presentSourceTypeSelection(
        from view: AccountImportViewProtocol?,
        availableSources: [AccountImportSource],
        selectedSource: AccountImportSource,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func presentCryptoTypeSelection(
        from view: AccountImportViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func presentNetworkTypeSelection(
        from view: AccountImportViewProtocol?,
        availableTypes: [Chain],
        selectedType: Chain,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

protocol AccountImportViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding() -> AccountImportViewProtocol?
    static func createViewForAdding() -> AccountImportViewProtocol?
    static func createViewForSwitch() -> AccountImportViewProtocol?
}
