import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

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
                   supportedNetworks: Chain.allCases,
                   defaultNetwork: settings.selectedConnection.type.chain)
    }

    private func importAccountItem(_ item: AccountItem) {
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

        let selectedConnection = settings.selectedConnection

        let connectionOperation: BaseOperation<(AccountItem, ConnectionItem)> = ClosureOperation {
            if case .failure(let error) = persistentOperation.result {
                throw error
            }

            let type = try SS58AddressFactory().type(fromAddress: item.address)

            let resultConnection: ConnectionItem

            if selectedConnection.type == SNAddressType(rawValue: type.uint8Value) {
                resultConnection = selectedConnection
            } else if let connection = ConnectionItem.supportedConnections
                        .first(where: { $0.type.rawValue == type.uint8Value}) {
                resultConnection = connection
            } else {
                throw AccountCreateError.unsupportedNetwork
            }

            return (item, resultConnection)
        }

        connectionOperation.addDependency(persistentOperation)

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch connectionOperation.result {
                case .success(let (accountItem, connectionItem)):
                    self?.settings.selectedAccount = accountItem

                    if selectedConnection != connectionItem {
                        self?.settings.selectedConnection = connectionItem

                        self?.eventCenter.notify(with: SelectedConnectionChanged())
                    }

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

        operationManager.enqueue(operations: [checkOperation, persistentOperation, connectionOperation],
                                 in: .sync)
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
