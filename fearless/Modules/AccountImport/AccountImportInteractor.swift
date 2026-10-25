import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit

final class AccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SelectedWalletSettings
    private(set) var eventCenter: EventCenterProtocol
    private let walletRecordsInspector: StoredWalletRecordsInspecting

    init(
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        settings: SelectedWalletSettings,
        keystoreImportService: KeystoreImportServiceProtocol,
        eventCenter: EventCenterProtocol,
        defaultSource: AccountImportSource,
        walletRecordsInspector: StoredWalletRecordsInspecting =
            AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared).createStoredWalletRecordsInspector()
    ) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.walletRecordsInspector = walletRecordsInspector

        super.init(
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: operationManager,
            keystoreImportService: keystoreImportService,
            defaultSource: defaultSource
        )
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        let importedChainId = uniqueChainImportChainId
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation {
            try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        saveOperation.completionBlock = { [weak self] in
            let result = saveOperation.result
            saveOperation.completionBlock = nil
            DispatchQueue.main.async {
                guard self != nil else {
                    ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                    return
                }
                switch result {
                case .success:
                    do {
                        let accountItem = try importOperation
                            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        self?.settings.save(value: accountItem, runningCompletionIn: .main) { result in
                            switch result {
                            case let .success(savedAccount):
                                (importOperation as? PersistenceBoundKeychainOperation)?
                                    .commitKeychainChanges()
                                self?.useImportedChainAccount(
                                    from: accountItem, in: savedAccount, chainId: importedChainId
                                ) { wallet in
                                    if self?.settings.value == wallet {
                                        self?.eventCenter.notify(with: SelectedAccountChanged(account: wallet))
                                    }
                                    self?.presenter?.completeAccountImport(
                                        selectionIsCurrent: self?.settings.value == wallet
                                    )
                                }
                            case let .failure(error):
                                do {
                                    try (importOperation as? PersistenceBoundKeychainOperation)?
                                        .rollbackKeychainChanges()
                                    self?.presenter?.didReceiveAccountImport(error: error)
                                } catch let rollbackError {
                                    Logger.shared.error(
                                        "Wallet persistence and recovery-secret rollback failed: " +
                                            "\(error.localizedDescription); " +
                                            "\(rollbackError.localizedDescription)"
                                    )
                                    self?.presenter?.didReceiveAccountImport(error: rollbackError)
                                }
                            }
                        }
                    } catch {
                        self?.presenter?.didReceiveAccountImport(error: error)
                    }

                case let .failure(error):
                    self?.presenter?.didReceiveAccountImport(error: error)

                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        saveOperation.addDependency(importOperation)

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }

    /// A save never makes a stored alternative the account in use. Importing for a network
    /// an account the wallet already keeps there, unused, is the user's choice to use it,
    /// so switch to it. If the switch fails the import still stands and the account stays
    /// offered in the wallet's details.
    private func useImportedChainAccount(
        from importedWallet: MetaAccountModel,
        in savedWallet: MetaAccountModel,
        chainId: ChainModel.Id?,
        completion: @escaping (MetaAccountModel) -> Void
    ) {
        guard
            settings.value == savedWallet,
            let chainId,
            let imported = importedWallet.chainAccounts.first(where: {
                UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chainId)
            }),
            !savedWallet.chainAccounts.contains(imported)
        else {
            completion(savedWallet)
            return
        }

        let selectOperation = walletRecordsInspector.selectChainAccountOperation(
            ChainAccountSelectionUpdate(
                chainId: imported.chainId,
                selection: .chainAccount(accountId: imported.accountId, publicKey: imported.publicKey)
            ),
            walletId: savedWallet.metaId
        )

        selectOperation.completionBlock = { [weak self] in
            let result = selectOperation.result
            selectOperation.completionBlock = nil
            DispatchQueue.main.async {
                guard
                    let self,
                    let selectedWallet = try? result?.get()
                else {
                    completion(savedWallet)
                    return
                }

                // The optional chain choice must not restore an older selected wallet
                // or overwrite edits made while the inspector was running.
                let accepted = self.settings.save(
                    value: selectedWallet,
                    ifCurrentValueSatisfies: { $0 == savedWallet },
                    runningCompletionIn: .main,
                    completionClosure: { result in
                        completion((try? result.get()) ?? savedWallet)
                    }
                )
                if !accepted {
                    completion(savedWallet)
                }
            }
        }

        operationManager.enqueue(operations: [selectOperation], in: .transient)
    }
}
