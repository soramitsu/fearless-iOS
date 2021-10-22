import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

extension AddAccount {
    final class AccountConfirmInteractor: BaseAccountConfirmInteractor {
        private(set) var settings: SettingsManagerProtocol
        let eventCenter: EventCenterProtocol

        private var currentOperation: Operation?

        init(
            request: MetaAccountCreationRequest,
            mnemonic: IRMnemonicProtocol,
            accountOperationFactory: MetaAccountOperationFactoryProtocol,
            accountRepository: AnyDataProviderRepository<MetaAccountModel>,
            operationManager: OperationManagerProtocol,
            settings: SettingsManagerProtocol,
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

        private func handleResult(_ result: Result<(MetaAccountModel, ConnectionItem), Error>?) {
            switch result {
            case .success(let (accountItem, connectionItem)):
//                settings.selectedAccount = accountItem
//
//                if settings.selectedConnection != connectionItem {
//                    settings.selectedConnection = connectionItem
//
//                    eventCenter.notify(with: SelectedConnectionChanged())
//                }

                eventCenter.notify(with: SelectedAccountChanged())

                presenter?.didCompleteConfirmation()
            case let .failure(error):
                presenter?.didReceive(error: error)
            case .none:
                let error = BaseOperationError.parentOperationCancelled
                presenter?.didReceive(error: error)
            }
        }

        override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
            guard currentOperation == nil else {
                return
            }

            let selectedConnection = settings.selectedConnection

            let persistentOperation = accountRepository.saveOperation({
                let accountItem = try importOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return [accountItem]
            }, { [] })

            persistentOperation.addDependency(importOperation)

            operationManager.enqueue(
                operations: [importOperation, persistentOperation],
                in: .transient
            )
        }
    }
}
