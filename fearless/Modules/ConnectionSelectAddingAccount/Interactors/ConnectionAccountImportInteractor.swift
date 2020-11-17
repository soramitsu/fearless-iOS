import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

final class ConnectionAccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SettingsManagerProtocol
    let connectionItem: ConnectionItem
    let eventCenter: EventCenterProtocol

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
                   keystoreImportService: keystoreImportService,
                   supportedNetworks: [connectionItem.type.chain],
                   defaultNetwork: connectionItem.type.chain)
    }

    private func importAccountItem(_ item: AccountItem) {
        let selectedConnection = connectionItem

        let checkOperation = accountRepository.fetchOperation(by: item.address,
                                                              options: RepositoryFetchOptions())

        let persistentOperation = accountRepository.saveOperation({
            if try checkOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) != nil {
                throw AccountCreateError.duplicated
            }

            return [item]
        }, { [] })

        persistentOperation.addDependency(checkOperation)

        let connectionOperation: BaseOperation<(AccountItem, ConnectionItem)> = ClosureOperation {
            if case .failure(let error) = persistentOperation.result {
                throw error
            }

            let type = try SS58AddressFactory().type(fromAddress: item.address)

            guard type.uint8Value == selectedConnection.type.rawValue else {
                throw AccountCreateError.unsupportedNetwork
            }

            return (item, selectedConnection)
        }

        connectionOperation.addDependency(persistentOperation)

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch connectionOperation.result {
                case .success(let (accountItem, connectionItem)):
                    self?.settings.selectedAccount = accountItem
                    self?.settings.selectedConnection = connectionItem

                    self?.eventCenter.notify(with: SelectedConnectionChanged())
                    self?.eventCenter.notify(with: SelectedAccountChanged())

                    self?.presenter?.didCompleteAccountImport()
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [checkOperation, persistentOperation, connectionOperation], in: .sync)
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        importOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch importOperation.result {
                case .success(let accountItem):
                    self?.importAccountItem(accountItem)
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation], in: .sync)
    }
}
