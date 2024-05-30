import IrohaCrypto
import SoraFoundation
import SSFModels

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func set(chainType: AccountCreateChainType)
    func setSelectedSubstrateCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)
    func setEthereumCrypto(model: TitleWithSubtitleViewModel)
    func bind(substrateViewModel: InputViewModelProtocol)
    func bind(ethereumViewModel: InputViewModelProtocol)

    func didCompleteCryptoTypeSelection()
    func didValidateSubstrateDerivationPath(_ status: FieldStatus)
    func didValidateEthereumDerivationPath(_ status: FieldStatus)
}

protocol AccountCreatePresenterProtocol: AnyObject {
    var flow: AccountCreateFlow { get }
    func setup()
    func selectSubstrateCryptoType()
    func activateInfo()
    func validateSubstrate()
    func validateEthereum()
    func proceed(withReplaced flow: AccountCreateFlow?)
    func didTapBackupButton()
}

protocol AccountCreateInteractorInputProtocol: AnyObject {
    func setup()
    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol?
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(mnemonic: [String])
    func didReceiveMnemonicGeneration(error: Error)
}

protocol AccountCreateWireframeProtocol: SheetAlertPresentable, ErrorPresentable {
    func confirm(
        from view: AccountCreateViewProtocol?,
        flow: AccountConfirmFlow
    )

    func presentCryptoTypeSelection(
        from view: AccountCreateViewProtocol?,
        availableTypes: [CryptoType],
        selectedType: CryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func showBackupCreatePassword(
        request: MetaAccountImportMnemonicRequest,
        from view: ControllerBackedProtocol?
    )
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(
        model: UsernameSetupModel,
        flow: AccountCreateFlow
    ) -> AccountCreateViewProtocol?
    static func createViewForAdding(
        model: UsernameSetupModel
    ) -> AccountCreateViewProtocol?
    static func createViewForSwitch(
        model: UsernameSetupModel
    ) -> AccountCreateViewProtocol?
}
