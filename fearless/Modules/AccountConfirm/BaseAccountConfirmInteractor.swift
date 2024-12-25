import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood
import SSFModels

class BaseAccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let flow: AccountConfirmFlow?
    let shuffledWords: [String]
    let accountOperationFactory: MetaAccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol

    init(
        flow: AccountConfirmFlow?,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.flow = flow
        shuffledWords = flow?.mnemonicAllWordls.shuffled() ?? []
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
        guard let confirmFlow = flow, words == confirmFlow.mnemonicAllWordls else {
            presenter.didReceive(
                words: shuffledWords,
                afterConfirmationFail: true
            )
            return
        }
        switch confirmFlow {
        case let .wallet(ecosystem):
            createAccount(ecosystem: ecosystem, isBackuped: true)
        case let .chain(request):
            importUniqueChain(request)
        }
    }

    func skipConfirmation() {
        guard let confirmFlow = flow else {
            return
        }
        switch confirmFlow {
        case let .wallet(request):
            createAccount(ecosystem: request, isBackuped: false)
        case let .chain(request):
            importUniqueChain(request)
        }
    }
}

private extension BaseAccountConfirmInteractor {
    func createAccount(ecosystem: AccountConfirmFlowWalletEcosystemRequest, isBackuped: Bool) {
        switch ecosystem {
        case let .regular(metaAccountImportMnemonicRequest):
            let operation = accountOperationFactory.newMetaAccountOperation(request: metaAccountImportMnemonicRequest, isBackedUp: isBackuped)
            createAccountUsingOperation(operation)
        case let .ton(metaAccountImportTonMnemonicRequest):
            let operation = accountOperationFactory.newTonMetaAccountOperation(request: metaAccountImportTonMnemonicRequest, isBackedUp: isBackuped)
            createAccountUsingOperation(operation)
        }
    }

    func importUniqueChain(_ request: ChainAccountImportMnemonicRequest) {
        let operation = accountOperationFactory.importChainAccountOperation(request: request)
        createAccountUsingOperation(operation)
    }
}
