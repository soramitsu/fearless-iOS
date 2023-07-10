import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func show(chainType: AccountCreateChainType)
    func setSource(type: AccountImportSource, chainType: AccountCreateChainType, selectable: Bool)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol, visible: Bool)
    func setPassword(viewModel: InputViewModelProtocol)
    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)
    func bind(substrateViewModel: InputViewModelProtocol)
    func bind(ethereumViewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)
    func setUniqueChain(viewModel: UniqueChainViewModel)
    func didChangeState(_ state: ErrorPresentableInputField.State)

    func didCompleteSourceTypeSelection()
    func didCompleteCryptoTypeSelection()

    func didValidateSubstrateDerivationPath(_ status: FieldStatus)
    func didValidateEthereumDerivationPath(_ status: FieldStatus)
}

protocol AccountImportPresenterProtocol: AnyObject {
    var flow: AccountImportFlow { get }

    func setup()
    func selectSourceType()
    func selectCryptoType()
    func activateUpload()
    func validateSubstrateDerivationPath()
    func validateEthereumDerivationPath()
    func proceed()
    func validateInput(value: String)
}

protocol AccountImportInteractorInputProtocol: AnyObject {
    func setup()
    func importMetaAccount(request: MetaAccountImportRequest)
    func importUniqueChain(request: UniqueChainImportRequest)
    func deriveMetadataFromKeystore(_ keystore: String)
    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol?
}

protocol AccountImportInteractorOutputProtocol: AnyObject {
    func didReceiveAccountImport(metadata: MetaAccountImportMetadata)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Error)
    func didSuggestKeystore(text: String, preferredInfo: MetaAccountImportPreferredInfo?)
    func didFailToDeriveMetadataFromKeystore()
}

protocol AccountImportWireframeProtocol: SheetAlertPresentable, ErrorPresentable, DocumentPickerPresentable {
    func showSecondStep(from view: AccountImportViewProtocol?, with data: AccountCreationStep.FirstStepData)

    func proceed(from view: AccountImportViewProtocol?, flow: AccountImportFlow)

    func presentSourceTypeSelection(
        from view: AccountImportViewProtocol?,
        availableSources: [AccountImportSource],
        selectedSource: AccountImportSource,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func presentCryptoTypeSelection(
        from view: AccountImportViewProtocol?,
        availableTypes: [CryptoType],
        selectedType: CryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

protocol AccountImportViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(
        defaultSource: AccountImportSource,
        flow: AccountImportFlow
    ) -> AccountImportViewProtocol?
    static func createViewForAdding(_ flow: AccountImportFlow) -> AccountImportViewProtocol?
    static func createViewForSwitch() -> AccountImportViewProtocol?
}

extension AccountImportViewFactoryProtocol {
    static func createViewForOnboarding(defaultSource: AccountImportSource) -> AccountImportViewProtocol? {
        Self.createViewForOnboarding(defaultSource: defaultSource, flow: .wallet(step: .first))
    }
}
