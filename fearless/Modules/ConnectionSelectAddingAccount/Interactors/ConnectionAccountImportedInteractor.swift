import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

final class ConnectionAccountImportedInteractor: BaseAccountImportInteractor {
    private(set) var settings: SettingsManagerProtocol
    let connectionItem: ConnectionItem
    let eventCenter: EventCenterProtocol

    override var availableAddressTypes: [SNAddressType] { [connectionItem.type] }

    init(connectionItem: ConnectionItem,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SettingsManagerProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         eventCenter: EventCenterProtocol) {
        self.settings = settings
        self.connectionItem = connectionItem
        self.eventCenter = eventCenter

        super.init(accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager,
                   keystoreImportService: keystoreImportService)
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
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
                throw AccountImportError.unsupportedNetwork
            }

            return (accountItem, selectedConnection)
        }

        connectionOperation.addDependency(persistentOperation)

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch connectionOperation.result {
                case .success(let (accountItem, connectionItem)):
                    self?.settings.selectedAccount = accountItem
                    self?.settings.selectedConnection = connectionItem

                    self?.presenter?.didCompleAccountImport()

                    self?.eventCenter.notify(with: SelectedConnectionChanged())
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
