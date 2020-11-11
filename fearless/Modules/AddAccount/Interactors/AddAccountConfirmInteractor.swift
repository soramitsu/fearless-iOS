import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class AddAccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol

    private var currentOperation: Operation?

    init(request: AccountCreationRequest,
         mnemonic: IRMnemonicProtocol,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(request: request,
                   mnemonic: mnemonic,
                   accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager)
    }

    private func handleResult(_ result: Result<(AccountItem, ConnectionItem), Error>?) {
        switch result {
        case .success(let (accountItem, connectionItem)):
            settings.selectedAccount = accountItem

            if settings.selectedConnection != connectionItem {
                settings.selectedConnection = connectionItem

                eventCenter.notify(with: SelectedConnectionChanged())
            }

            eventCenter.notify(with: SelectedAccountChanged())

            presenter?.didCompleteConfirmation()
        case .failure(let error):
            presenter?.didReceive(error: error)
        case .none:
            let error = BaseOperationError.parentOperationCancelled
            presenter?.didReceive(error: error)
        }
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
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

        let connectionOperation: BaseOperation<(AccountItem, ConnectionItem)> = ClosureOperation {
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let type = try SS58AddressFactory().type(fromAddress: accountItem.address)

            let resultConnection: ConnectionItem

            if selectedConnection.type == SNAddressType(rawValue: type.uint8Value) {
                resultConnection = selectedConnection
            } else if let connection = ConnectionItem.supportedConnections
                        .first(where: { $0.type.rawValue == type.uint8Value}) {
                resultConnection = connection
            } else {
                throw AccountCreateError.unsupportedNetwork
            }

            return (accountItem, resultConnection)
        }

        connectionOperation.addDependency(persistentOperation)

        currentOperation = connectionOperation

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                self?.handleResult(connectionOperation.result)
            }
        }

        operationManager.enqueue(operations: [importOperation, persistentOperation, connectionOperation],
                                 in: .sync)
    }
}
