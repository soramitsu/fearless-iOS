import UIKit
import RobinHood

final class WalletMainContainerInteractor {
    // MARK: - Private properties

    private weak var output: WalletMainContainerInteractorOutput?

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private var selectedMetaAccount: MetaAccountModel
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol

    // MARK: - Constructor

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        selectedMetaAccount: MetaAccountModel,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
    }

    // MARK: - Private methods

    private func fetchSelectedChainName() {
        guard let chainId = selectedMetaAccount.chainIdForFilter else {
            output?.didReceiveSelectedChain(nil)
            return
        }

        let operation = chainRepository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                self?.output?.didReceiveError(BaseOperationError.unexpectedDependentResult)
                return
            }

            switch result {
            case let .success(chain):
                self?.output?.didReceiveSelectedChain(chain)
            case let .failure(error):
                self?.output?.didReceiveError(error)
            }
        }

        operationQueue.addOperation(operation)
    }

    private func save(
        _ updatedAccount: MetaAccountModel
    ) {
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    self?.selectedMetaAccount = account
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                    self?.fetchSelectedChainName()
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}

// MARK: - WalletMainContainerInteractorInput

extension WalletMainContainerInteractor: WalletMainContainerInteractorInput {
    func saveChainIdForFilter(_ chainId: ChainModel.Id?) {
        var updatedAccount: MetaAccountModel?

        if chainId != selectedMetaAccount.chainIdForFilter {
            updatedAccount = selectedMetaAccount.replacingChainIdForFilter(chainId)
        }

        if let updatedAccount = updatedAccount {
            save(updatedAccount)
        }
    }

    func setup(with output: WalletMainContainerInteractorOutput) {
        self.output = output
        eventCenter.add(observer: self, dispatchIn: .global())
        fetchSelectedChainName()
    }
}

// MARK: - EventVisitorProtocol

extension WalletMainContainerInteractor: EventVisitorProtocol {
    func processWalletNameChanged(event: WalletNameChanged) {
        selectedMetaAccount = event.wallet
        output?.didReceiveAccount(selectedMetaAccount)
    }
}
