import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class ConnectionAccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SettingsManagerProtocol
    private var currentOperation: Operation?

    let eventCenter: EventCenterProtocol
    let connectionItem: ConnectionItem

    init(connectionItem: ConnectionItem,
         request: AccountCreationRequest,
         mnemonic: IRMnemonicProtocol,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol) {
        self.settings = settings
        self.connectionItem = connectionItem
        self.eventCenter = eventCenter

        super.init(request: request,
                   mnemonic: mnemonic,
                   accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager)
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        guard currentOperation == nil else {
            return
        }

        let selectedConnection = connectionItem

        let persistentOperation = accountRepository.saveOperation({
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return [accountItem]
        }, { [] })

        persistentOperation.addDependency(importOperation)

        let connectionOperation: BaseOperation<(AccountItem, ConnectionItem)> = ClosureOperation {
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let type = try SS58AddressFactory().type(fromAddress: accountItem.address)

            guard type.uint8Value == selectedConnection.type.rawValue else {
                throw AccountCreateError.unsupportedNetwork
            }

            return (accountItem, selectedConnection)
        }

        connectionOperation.addDependency(persistentOperation)

        currentOperation = connectionOperation

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                switch connectionOperation.result {
                case .success(let (accountItem, connectionItem)):
                    self?.settings.selectedAccount = accountItem
                    self?.settings.selectedConnection = connectionItem

                    self?.eventCenter.notify(with: SelectedConnectionChanged())
                    self?.eventCenter.notify(with: SelectedAccountChanged())

                    self?.presenter?.didCompleteConfirmation()
                case .failure(let error):
                    self?.presenter?.didReceive(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation, persistentOperation, connectionOperation],
                                 in: .sync)
    }
}
