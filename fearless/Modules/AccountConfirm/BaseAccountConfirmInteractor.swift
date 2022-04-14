import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class BaseAccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let flow: AccountConfirmFlow
    let shuffledWords: [String]
    let accountOperationFactory: MetaAccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol

    init(
        flow: AccountConfirmFlow,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.flow = flow
        shuffledWords = flow.mnemonic.allWords().shuffled()
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
    }

    internal func createAccountUsingOperation(_: BaseOperation<MetaAccountModel>) {
        fatalError("This function should be overriden")
    }
}

extension BaseAccountConfirmInteractor: AccountConfirmInteractorInputProtocol {
    func requestWords() {
        presenter.didReceive(words: shuffledWords, afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        guard words == flow.mnemonic.allWords() else {
            presenter.didReceive(
                words: shuffledWords,
                afterConfirmationFail: true
            )
            return
        }
        switch flow {
        case let .wallet(request):
            createAccount(request)
        case let .chain(request):
            importUniqueChain(request)
        }
    }

    func skipConfirmation() {
        switch flow {
        case let .wallet(request):
            createAccount(request)
        case let .chain(request):
            importUniqueChain(request)
        }
    }
}

private extension BaseAccountConfirmInteractor {
    func createAccount(_ request: MetaAccountImportMnemonicRequest) {
        let operation = accountOperationFactory.newMetaAccountOperation(request: request)
        createAccountUsingOperation(operation)
    }

    func importUniqueChain(_ request: ChainAccountImportMnemonicRequest) {
        let operation = accountOperationFactory.importChainAccountOperation(request: request)
        createAccountUsingOperation(operation)
    }
}
