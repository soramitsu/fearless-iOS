import Foundation
import RobinHood
import SoraKeystore
import SSFAccountManagmentStorage
import SSFKeyPair
import SSFModels
import SSFUtils

enum CreateAccountError: Error {
    case invalidMnemonicSize
    case invalidMnemonicFormat
    case invalidSeed
    case invalidKeystore
    case unsupportedNetwork
    case duplicated
}

// sourcery: AutoMockable
public protocol AccountImportable {
    func importMetaAccount(request: MetaAccountImportRequest) async throws -> MetaAccountModel
}

public final class AccountImportService {
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let accountOperationFactory: MetaAccountOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let mnemonicCreator: MnemonicCreator
    private let selectedWallet: PersistentValueSettings<MetaAccountModel>

    public init(
        accountOperationFactory: MetaAccountOperationFactoryProtocol =
            MetaAccountOperationFactory(keystore: Keychain()),
        storageFacade: StorageFacadeProtocol,
        mnemonicCreator: MnemonicCreator = MnemonicCreatorImpl(),
        operationManager: OperationManagerProtocol = OperationManager(),
        selectedWallet: PersistentValueSettings<MetaAccountModel>
    ) {
        accountRepository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(
                for: nil,
                sortDescriptors: []
            )

        self.accountOperationFactory = accountOperationFactory
        self.operationManager = operationManager
        self.mnemonicCreator = mnemonicCreator
        self.selectedWallet = selectedWallet
    }
}

extension AccountImportService: AccountImportable {
    public func importMetaAccount(request: MetaAccountImportRequest) async throws
        -> MetaAccountModel
    {
        let operation: BaseOperation<MetaAccountModel>
        switch request.source {
        case let .mnemonic(data):
            guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: data.mnemonic) else {
                throw CreateAccountError.invalidMnemonicFormat
            }

            let request = MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic,
                username: request.username,
                substrateDerivationPath: data.substrateDerivationPath,
                ethereumDerivationPath: data.ethereumDerivationPath,
                cryptoType: request.cryptoType,
                defaultChainId: request.defaultChainId
            )
            operation = accountOperationFactory.newMetaAccountOperation(
                mnemonicRequest: request,
                isBackuped: true
            )
        case let .seed(data):
            let request = MetaAccountImportSeedRequest(
                substrateSeed: data.substrateSeed,
                ethereumSeed: data.ethereumSeed,
                username: request.username,
                substrateDerivationPath: data.substrateDerivationPath,
                ethereumDerivationPath: data.ethereumDerivationPath,
                cryptoType: request.cryptoType
            )
            operation = accountOperationFactory.newMetaAccountOperation(
                seedRequest: request,
                isBackuped: true
            )
        case let .keystore(data):
            let request = MetaAccountImportKeystoreRequest(
                substrateKeystore: data.substrateKeystore,
                ethereumKeystore: data.ethereumKeystore,
                substratePassword: data.substratePassword,
                ethereumPassword: data.ethereumPassword,
                username: request.username,
                cryptoType: request.cryptoType
            )
            operation = accountOperationFactory.newMetaAccountOperation(
                keystoreRequest: request,
                isBackuped: true
            )
        }
        operationManager.enqueue(operations: [operation], in: .transient)

        return try await withUnsafeThrowingContinuation { continuation in
            operation.completionBlock = { [weak self] in
                switch operation.result {
                case let .success(accountItem):
                    self?.saveOperation(with: accountItem, continuation: continuation)

                case let .failure(error):
                    continuation.resume(throwing: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func saveOperation(
        with item: MetaAccountModel,
        continuation: UnsafeContinuation<MetaAccountModel, Error>
    ) {
        let checkOperation = accountRepository.fetchOperation(
            by: item.identifier,
            options: RepositoryFetchOptions()
        )

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            if try checkOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) != nil
            {
                throw CreateAccountError.duplicated
            }

            self?.selectedWallet.save(value: item)
            return item
        }

        saveOperation.addDependency(checkOperation)
        operationManager.enqueue(operations: [checkOperation, saveOperation], in: .transient)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    self?.selectedWallet.setup()
                    continuation.resume(returning: item)

                case let .failure(error):
                    continuation.resume(throwing: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
