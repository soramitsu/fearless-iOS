import UIKit
import IrohaCrypto
import SSFUtils
import RobinHood
import FearlessSecureStorage

final class AccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SelectedWalletSettings
    private(set) var eventCenter: EventCenterProtocol

    init(
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        settings: SelectedWalletSettings,
        keystoreImportService: KeystoreImportServiceProtocol,
        eventCenter: EventCenterProtocol,
        defaultSource: AccountImportSource
    ) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: operationManager,
            keystoreImportService: keystoreImportService,
            defaultSource: defaultSource
        )
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation {
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return accountItem
        }

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    do {
                        let accountItem = try importOperation
                            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        self?.settings.save(value: accountItem, runningCompletionIn: .main) { result in
                            switch result {
                            case let .success(savedAccount):
                                self?.eventCenter.notify(with: SelectedAccountChanged(account: savedAccount))
                                self?.presenter?.didCompleteAccountImport()
                            case let .failure(error):
                                self?.presenter?.didReceiveAccountImport(error: error)
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
}
