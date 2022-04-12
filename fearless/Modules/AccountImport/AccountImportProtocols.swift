import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func show(chainType: AccountCreateChainType)
    func setSource(type: AccountImportSource, selectable: Bool)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol)
    func setPassword(viewModel: InputViewModelProtocol)
    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)
    func bind(substrateViewModel: InputViewModelProtocol)
    func bind(ethereumViewModel: InputViewModelProtocol)
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
    func showSecondStep(from view: AccountImportViewProtocol?, with data: AccountCreationStep.FirstStepData)

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
        availableTypes: [CryptoType],
        selectedType: CryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func presentSelectFilePicker(
        from view: AccountImportViewProtocol?,
        delegate: UIDocumentPickerDelegate
    )
}

protocol AccountImportViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(_ step: AccountCreationStep) -> AccountImportViewProtocol?
    static func createViewForAdding(_ step: AccountCreationStep) -> AccountImportViewProtocol?
    static func createViewForSwitch() -> AccountImportViewProtocol?
}

extension AccountImportViewFactoryProtocol {
    static func createViewForOnboarding() -> AccountImportViewProtocol? {
        Self.createViewForOnboarding(.first)
    }
}

extension AccountImportWireframeProtocol {
    func presentSelectFilePicker(
        from view: AccountImportViewProtocol?,
        delegate: UIDocumentPickerDelegate
    ) {
        let controller = UIDocumentPickerViewController(
            documentTypes: ["public.json"],
            in: .import
        )
        controller.delegate = delegate
        controller.allowsMultipleSelection = false
        controller.modalPresentationStyle = .formSheet
        view?.controller.navigationController?.present(
            controller,
            animated: true,
            completion: nil
        )
    }
}
