import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

enum AddAccountImportInteractorError: Error {
    case unsupportedNetwork
}

final class AddAccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SettingsManagerProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         eventCenter: EventCenterProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager,
                   keystoreImportService: keystoreImportService,
                   supportedAddressTypes: SNAddressType.supported,
                   defaultAddressType: settings.selectedConnection.type)
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        let persistentOperation = accountRepository.saveOperation({
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return [accountItem]
        }, { [] })

        persistentOperation.addDependency(importOperation)

        let selectedConnection = settings.selectedConnection

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
                throw AddAccountImportInteractorError.unsupportedNetwork
            }

            return (accountItem, resultConnection)
        }

        connectionOperation.addDependency(persistentOperation)

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch connectionOperation.result {
                case .success(let (accountItem, connectionItem)):
                    self?.settings.selectedAccount = accountItem

                    let connectionChanged = selectedConnection != connectionItem

                    if connectionChanged {
                        self?.settings.selectedConnection = connectionItem
                    }

                    self?.presenter?.didCompleAccountImport()

                    if connectionChanged {
                        self?.eventCenter.notify(with: SelectedConnectionChanged())
                    }

                    self?.eventCenter.notify(with: SelectedAccountChanged())
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation, persistentOperation, connectionOperation],
                                 in: .sync)
    }
}
