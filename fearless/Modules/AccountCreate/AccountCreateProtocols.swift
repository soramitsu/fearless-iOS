import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedCrypto(model: TitleWithSubtitleViewModel)
    func setDerivationPath(viewModel: InputViewModelProtocol)

    func didCompleteCryptoTypeSelection()
    func didValidateDerivationPath(_ status: FieldStatus)
}

protocol AccountCreatePresenterProtocol: AnyObject {
    func setup()
    func selectCryptoType()
    func activateInfo()
    func validate()
    func proceed()
}

protocol AccountCreateInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(metadata: AccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable {
    func confirm(
        from view: AccountCreateViewProtocol?,
        request: AccountCreationRequest,
        metadata: AccountCreationMetadata
    )

    func presentCryptoTypeSelection(
        from view: AccountCreateViewProtocol?,
        availableTypes: [CryptoType],
        selectedType: CryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(model: UsernameSetupModel) -> AccountCreateViewProtocol?
    static func createViewForAdding(model: UsernameSetupModel) -> AccountCreateViewProtocol?

    static func createViewForConnection(
        item: ConnectionItem,
        model: UsernameSetupModel
    ) -> AccountCreateViewProtocol?

    static func createViewForSwitch(model: UsernameSetupModel) -> AccountCreateViewProtocol?
}
