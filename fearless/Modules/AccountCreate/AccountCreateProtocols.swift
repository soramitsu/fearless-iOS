import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedCrypto(model: TitleWithSubtitleViewModel)
    func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)
    func setDerivationPath(viewModel: InputViewModelProtocol)

    func didCompleteCryptoTypeSelection()
    func didCompleteNetworkTypeSelection()
    func didValidateDerivationPath(_ status: FieldStatus)
}

protocol AccountCreatePresenterProtocol: AnyObject {
    func setup()
    func selectCryptoType()
    func selectNetworkType()
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
    func presentNetworkTypeSelection(
        from view: AccountCreateViewProtocol?,
        availableTypes: [Chain],
        selectedType: Chain,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(username: String) -> AccountCreateViewProtocol?
    static func createViewForAdding(username: String) -> AccountCreateViewProtocol?
    static func createViewForConnection(item: ConnectionItem, username: String) -> AccountCreateViewProtocol?
    static func createViewForSwitch(username: String) -> AccountCreateViewProtocol?
}
