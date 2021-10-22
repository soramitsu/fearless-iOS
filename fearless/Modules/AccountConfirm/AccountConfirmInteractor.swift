import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class AccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SelectedWalletSettings
    private var currentOperation: Operation?

    let eventCenter: EventCenterProtocol

    init(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        settings: SelectedWalletSettings,
        operationManager: OperationManagerProtocol,
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
//
//
//
//
//        let persistentOperation = accountRepository.saveOperation({
//            let accountItem = try importOperation
//                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            return [accountItem]
//        }, { [] })
//
//        persistentOperation.addDependency(importOperation)
//
//        let connectionOperation: BaseOperation<(AccountItem, ConnectionItem)> = ClosureOperation {
//            let accountItem = try importOperation
//                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//
//            let type = try SS58AddressFactory().type(fromAddress: accountItem.address)
//
//            guard let connectionItem = ConnectionItem.supportedConnections
//                .first(where: { $0.type.rawValue == type.uint8Value })
//            else {
//                throw AccountCreateError.unsupportedNetwork
//            }
//
//            return (accountItem, connectionItem)
//        }
//
//        connectionOperation.addDependency(persistentOperation)
//
//        currentOperation = connectionOperation
//
//        connectionOperation.completionBlock = { [weak self] in
//            DispatchQueue.main.async {
//                self?.currentOperation = nil
//
//                switch connectionOperation.result {
//                case .success(let (accountItem, connectionItem)):
//                    self?.settings.selectedAccount = accountItem
//                    self?.settings.selectedConnection = connectionItem
//
//                    self?.presenter?.didCompleteConfirmation()
//                case let .failure(error):
//                    self?.presenter?.didReceive(error: error)
//                case .none:
//                    let error = BaseOperationError.parentOperationCancelled
//                    self?.presenter?.didReceive(error: error)
//                }
//            }
//        }
//
//        operationManager.enqueue(
//            operations: [importOperation, persistentOperation, connectionOperation],
//            in: .transient
//        )
    }
}

/*
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
         case let .failure(error):
             self?.presenter?.didReceive(error: error)
         case .none:
             let error = BaseOperationError.parentOperationCancelled
             self?.presenter?.didReceive(error: error)
         }
     }
 }

 operationManager.enqueue(
     operations: [importOperation, persistentOperation, connectionOperation],
     in: .transient
 )

 */
