import IrohaCrypto
import SoraFoundation

struct AccountCreationMetadata {
    let mnemonic: [String]
    let availableAccountTypes: [SNAddressType]
    let defaultAccountType: SNAddressType
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}

struct AccountCreationRequest {
    let username: String
    let type: SNAddressType
    let derivationPath: String
    let cryptoType: CryptoType
}

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedCrypto(model: TitleWithSubtitleViewModel)
    func setSelectedNetwork(model: IconWithTitleViewModel)
    func setDerivationPath(viewModel: InputViewModelProtocol)

    func didCompleteCryptoTypeSelection()
    func didCompleteNetworkTypeSelection()
}

protocol AccountCreatePresenterProtocol: class {
    func setup()
    func selectCryptoType()
    func selectNetworkType()
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

protocol AccountCreateWireframeProtocol: class {
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
