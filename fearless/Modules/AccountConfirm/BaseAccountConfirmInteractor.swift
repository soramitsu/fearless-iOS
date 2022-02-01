import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class BaseAccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let request: MetaAccountCreationRequest
    let mnemonic: IRMnemonicProtocol
    let shuffledWords: [String]
    let accountOperationFactory: MetaAccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol

    init(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.request = request
        self.mnemonic = mnemonic
        shuffledWords = mnemonic.allWords().shuffled()
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
        guard words == mnemonic.allWords() else {
            presenter.didReceive(
                words: shuffledWords,
                afterConfirmationFail: true
            )
            return
        }

        let operation = accountOperationFactory.newMetaAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        createAccountUsingOperation(operation)
    }

    func skipConfirmation() {
        let operation = accountOperationFactory.newMetaAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        createAccountUsingOperation(operation)
    }
}
