import UIKit
import IrohaCrypto
import SSFUtils
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
    let defaultSource: AccountImportSource

    init(
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        defaultSource: AccountImportSource
    ) {
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.keystoreImportService = keystoreImportService
        self.defaultSource = defaultSource
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
            defaultSource: defaultSource,
            availableCryptoTypes: CryptoType.allCases,
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

    func importMetaAccount(request: MetaAccountImportRequest) {
        let operation: BaseOperation<MetaAccountModel>
        switch request.source {
        case let .mnemonic(data):
            let request = MetaAccountImportMnemonicRequest(
                mnemonic: data.mnemonic,
                username: request.username,
                substrateDerivationPath: data.substrateDerivationPath,
                ethereumDerivationPath: data.ethereumDerivationPath,
                cryptoType: request.cryptoType,
                defaultChainId: request.defaultChainId
            )
            operation = accountOperationFactory.newMetaAccountOperation(request: request, isBackuped: true)
        case let .seed(data):
            let request = MetaAccountImportSeedRequest(
                substrateSeed: data.substrateSeed,
                ethereumSeed: data.ethereumSeed,
                username: request.username,
                substrateDerivationPath: data.substrateDerivationPath,
                ethereumDerivationPath: data.ethereumDerivationPath,
                cryptoType: request.cryptoType
            )
            operation = accountOperationFactory.newMetaAccountOperation(request: request, isBackuped: true)
        case let .keystore(data):
            let request = MetaAccountImportKeystoreRequest(
                substrateKeystore: data.substrateKeystore,
                ethereumKeystore: data.ethereumKeystore,
                substratePassword: data.substratePassword,
                ethereumPassword: data.ethereumPassword,
                username: request.username,
                cryptoType: request.cryptoType
            )
            operation = accountOperationFactory.newMetaAccountOperation(request: request, isBackuped: true)
        }
        importAccountUsingOperation(operation)
    }

    func importUniqueChain(request: UniqueChainImportRequest) {
        let operation: BaseOperation<MetaAccountModel>
        switch request.source {
        case let .mnemonic(data):
            let request = ChainAccountImportMnemonicRequest(
                mnemonic: data.mnemonic,
                username: request.username,
                derivationPath: data.derivationPath,
                cryptoType: request.cryptoType,
                isEthereum: request.chain.isEthereumBased,
                meta: request.meta,
                chainId: request.chain.chainId
            )
            operation = accountOperationFactory.importChainAccountOperation(request: request)
        case let .seed(data):
            let request = ChainAccountImportSeedRequest(
                seed: data.seed,
                username: request.username,
                derivationPath: data.derivationPath,
                cryptoType: request.cryptoType,
                isEthereum: request.chain.isEthereumBased,
                meta: request.meta,
                chainId: request.chain.chainId
            )
            operation = accountOperationFactory.importChainAccountOperation(request: request)
        case let .keystore(data):
            let request = ChainAccountImportKeystoreRequest(
                keystore: data.keystore,
                password: data.password,
                username: request.username,
                cryptoType: request.cryptoType,
                isEthereum: request.chain.isEthereumBased,
                meta: request.meta,
                chainId: request.chain.chainId
            )
            operation = accountOperationFactory.importChainAccountOperation(request: request)
        }
        importAccountUsingOperation(operation)
    }

    func deriveMetadataFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data),
            let info = try? AccountImportJsonFactory().createInfo(from: definition) {
            presenter.didSuggestKeystore(text: keystore, preferredInfo: info)
        } else {
            presenter.didFailToDeriveMetadataFromKeystore()
        }
    }

    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol? {
        try? mnemonicCreator.mnemonic(fromList: mnemonicString)
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
