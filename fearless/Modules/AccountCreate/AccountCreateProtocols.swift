import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedSubstrateCrypto(model: TitleWithSubtitleViewModel)
    func setEthereumCrypto(model: TitleWithSubtitleViewModel)
    func bind(substrateViewModel: InputViewModelProtocol)
    func bind(ethereumViewModel: InputViewModelProtocol)

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
        availableTypes: [CryptoType],
        selectedType: CryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(
        model: UsernameSetupModel,
        chainType: AccountCreateChainType
    ) -> AccountCreateViewProtocol?
    static func createViewForAdding(
        model: UsernameSetupModel,
        chainType: AccountCreateChainType
    ) -> AccountCreateViewProtocol?
    static func createViewForSwitch(
        model: UsernameSetupModel,
        chainType: AccountCreateChainType
    ) -> AccountCreateViewProtocol?
}
