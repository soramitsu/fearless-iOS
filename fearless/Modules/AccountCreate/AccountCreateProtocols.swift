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
    func setSelectedCrypto(title: String)
    func setSelectedNetwork(title: String)
    func setDerivationPath(viewModel: InputViewModelProtocol)
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
}

protocol AccountCreateViewFactoryProtocol: class {
	static func createView() -> AccountCreateViewProtocol?
}
