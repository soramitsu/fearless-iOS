import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedSubstrateCrypto(model: TitleWithSubtitleViewModel)
    func setEthereumCrypto(model: TitleWithSubtitleViewModel)
    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol)
    func setEthereumDerivationPath(viewModel: InputViewModelProtocol)

    func didCompleteCryptoTypeSelection()
    func didValidateSubstrateDerivationPath(_ status: FieldStatus)
    func didValidateEthereumDerivationPath(_ status: FieldStatus)
}

protocol AccountCreatePresenterProtocol: AnyObject {
    func setup()
    func selectSubstrateCryptoType()
    func activateInfo()
    func validateSubstrate()
    func validateEthereum()
    func proceed()
}

protocol AccountCreateInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(mnemonic: [String])
    func didReceiveMnemonicGeneration(error: Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable {
    func confirm(
        from view: AccountCreateViewProtocol?,
        request: MetaAccountCreationRequest,
        mnemonic: [String]
    )

    func presentCryptoTypeSelection(
        from view: AccountCreateViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(model: UsernameSetupModel) -> AccountCreateViewProtocol?
    static func createViewForAdding(model: UsernameSetupModel) -> AccountCreateViewProtocol?
    static func createViewForSwitch(model: UsernameSetupModel) -> AccountCreateViewProtocol?
}
