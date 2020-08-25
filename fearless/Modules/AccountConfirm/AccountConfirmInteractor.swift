import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

final class AccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let request: AccountCreationRequest
    let mnemonic: IRMnemonicProtocol
    let shuffledWords: [String]
    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol
    private(set) var settings: SettingsManagerProtocol

    private var currentOperation: Operation?

    init(request: AccountCreationRequest,
         mnemonic: IRMnemonicProtocol,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol) {
        self.request = request
        self.mnemonic = mnemonic
        self.shuffledWords = mnemonic.allWords().shuffled()
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.settings = settings
    }

    private func createAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        guard currentOperation == nil else {
            return
        }

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

            guard let connectionItem = ConnectionItem.supportedConnections
                .first(where: { $0.type == type.int8Value }) else {
                throw AccountImportError.unsupportedNetwork
            }

            return (accountItem, connectionItem)
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

extension AccountConfirmInteractor: AccountConfirmInteractorInputProtocol {
    func requestWords() {
        presenter.didReceive(words: shuffledWords, afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        guard words == mnemonic.allWords() else {
            presenter.didReceive(words: shuffledWords,
                                 afterConfirmationFail: true)
            return
        }

        let operation = accountOperationFactory.newAccountOperation(request: request,
                                                                    mnemonic: mnemonic)
        createAccountUsingOperation(operation)
    }
}
