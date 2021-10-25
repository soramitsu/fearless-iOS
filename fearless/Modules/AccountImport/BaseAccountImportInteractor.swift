import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

class BaseAccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let accountOperationFactory: MetaAccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let supportedNetworks: [Chain]
    let defaultNetwork: Chain

    init(
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        supportedNetworks: [Chain],
        defaultNetwork: Chain
    ) {
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.keystoreImportService = keystoreImportService
        self.supportedNetworks = supportedNetworks
        self.defaultNetwork = defaultNetwork
    }

    private func setupKeystoreImportObserver() {
        keystoreImportService.add(observer: self)
        handleIfNeededKeystoreImport()
    }

    private func handleIfNeededKeystoreImport() {
        if let definition = keystoreImportService.definition {
            keystoreImportService.clear()

            do {
                let jsonData = try JSONEncoder().encode(definition)
                let info = try AccountImportJsonFactory().createInfo(from: definition)

                if let text = String(data: jsonData, encoding: .utf8) {
                    presenter.didSuggestKeystore(text: text, preferredInfo: info)
                }

            } catch {
                presenter.didReceiveAccountImport(error: error)
            }
        }
    }

    private func provideMetadata() {
        let metadata = MetaAccountImportMetadata(
            availableSources: AccountImportSource.allCases,
            defaultSource: .mnemonic,
            availableNetworks: supportedNetworks,
            defaultNetwork: defaultNetwork,
            availableCryptoTypes: MultiassetCryptoType.allCases,
            defaultCryptoType: .sr25519
        )

        presenter.didReceiveAccountImport(metadata: metadata)
    }

    func importAccountUsingOperation(_: BaseOperation<MetaAccountModel>) {}
}

extension BaseAccountImportInteractor: AccountImportInteractorInputProtocol {
    func setup() {
        provideMetadata()
        setupKeystoreImportObserver()
    }

    func importAccountWithMnemonic(request: MetaAccountImportMnemonicRequest) {
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            presenter.didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            return
        }

        let creationRequest = MetaAccountCreationRequest(
            username: request.username,
            derivationPath: request.derivationPath,
            cryptoType: request.cryptoType
        )

        let accountOperation = accountOperationFactory.newMetaAccountOperation(
            request: creationRequest,
            mnemonic: mnemonic
        )

        importAccountUsingOperation(accountOperation)
    }

    func importAccountWithSeed(request: MetaAccountImportSeedRequest) {
        let operation = accountOperationFactory.newMetaAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(request: MetaAccountImportKeystoreRequest) {
        let operation = accountOperationFactory.newMetaAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func deriveMetadataFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data),
            let info = try? AccountImportJsonFactory().createInfo(from: definition) {
            presenter.didSuggestKeystore(text: keystore, preferredInfo: info)
        }
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
