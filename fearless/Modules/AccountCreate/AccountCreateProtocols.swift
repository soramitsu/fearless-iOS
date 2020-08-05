import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedCrypto(model: TitleWithSubtitleViewModel)
    func setSelectedNetwork(model: IconWithTitleViewModel)
    func setDerivationPath(viewModel: InputViewModelProtocol)

    func didCompleteCryptoTypeSelection()
    func didCompleteNetworkTypeSelection()
    func didValidateDerivationPath(_ status: FieldStatus)
}

protocol AccountCreatePresenterProtocol: class {
    func setup()
    func selectCryptoType()
    func selectNetworkType()
    func activateInfo()
    func validate()
    func proceed()
}

protocol AccountCreateInteractorInputProtocol: class {
    func setup()

    func createAccount(request: AccountCreationRequest)
}

protocol AccountCreateInteractorOutputProtocol: class {
    func didReceive(metadata: AccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Error)

    func didCompleteAccountCreation()
    func didReceiveAccountCreation(error: Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(from view: AccountCreateViewProtocol?)
    func presentCryptoTypeSelection(from view: AccountCreateViewProtocol?,
                                    availableTypes: [CryptoType],
                                    selectedType: CryptoType,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?)
    func presentNetworkTypeSelection(from view: AccountCreateViewProtocol?,
                                     availableTypes: [SNAddressType],
                                     selectedType: SNAddressType,
                                     delegate: ModalPickerViewControllerDelegate?,
                                     context: AnyObject?)
}

protocol AccountCreateViewFactoryProtocol: class {
    static func createView(username: String) -> AccountCreateViewProtocol?
}
