import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

// TODO: Check how to convert this to chain account import
extension AddAccount {
    final class AccountConfirmInteractor: BaseAccountConfirmInteractor {
        private(set) var settings: SelectedWalletSettings
        let eventCenter: EventCenterProtocol

        private var currentOperation: Operation?

        init(
            request: MetaAccountCreationRequest,
            mnemonic: IRMnemonicProtocol,
            accountOperationFactory: MetaAccountOperationFactoryProtocol,
            accountRepository: AnyDataProviderRepository<MetaAccountModel>,
            operationManager: OperationManagerProtocol,
            settings: SelectedWalletSettings,
            eventCenter: EventCenterProtocol
        ) {
            self.settings = settings
            self.eventCenter = eventCenter

            super.init(
                request: request,
                mnemonic: mnemonic,
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: operationManager
            )
        }

        override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
            guard currentOperation == nil else {
                return
            }

            let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
                let accountItem = try importOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                self?.settings.save(value: accountItem)

                return accountItem
            }

            saveOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    self?.currentOperation = nil

                    switch saveOperation.result {
                    case .success:
                        self?.settings.setup()
                        self?.eventCenter.notify(with: SelectedAccountChanged())
                        self?.presenter?.didCompleteConfirmation()

                    case let .failure(error):
                        self?.presenter?.didReceive(error: error)

                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        self?.presenter?.didReceive(error: error)
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
}
