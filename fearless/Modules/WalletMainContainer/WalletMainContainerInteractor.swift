import UIKit
import RobinHood

final class WalletMainContainerInteractor {
    // MARK: - Private properties

    private weak var output: WalletMainContainerInteractorOutput?

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private var wallet: MetaAccountModel
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol
    private let chainsIssuesCenter: ChainsIssuesCenter

    // MARK: - Constructor

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        wallet: MetaAccountModel,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        chainsIssuesCenter: ChainsIssuesCenter
    ) {
        self.wallet = wallet
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.chainsIssuesCenter = chainsIssuesCenter
    }

    // MARK: - Private methods

    private func fetchSelectedChainName() {
        guard let chainId = wallet.chainIdForFilter else {
            DispatchQueue.main.async {
                self.output?.didReceiveSelectedChain(nil)
            }
            return
        }

        let operation = chainRepository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                DispatchQueue.main.async {
                    self?.output?.didReceiveError(BaseOperationError.unexpectedDependentResult)
                }
                return
            }

            DispatchQueue.main.async {
                switch result {
                case let .success(chain):
                    self?.output?.didReceiveSelectedChain(chain)
                case let .failure(error):
                    self?.output?.didReceiveError(error)
                }
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
                    self?.wallet = account
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

        if chainId != wallet.chainIdForFilter {
            updatedAccount = wallet.replacingChainIdForFilter(chainId)
        }

        if let updatedAccount = updatedAccount {
            save(updatedAccount)
        }
    }

    func setup(with output: WalletMainContainerInteractorOutput) {
        self.output = output
        eventCenter.add(observer: self, dispatchIn: .main)
        chainsIssuesCenter.addIssuesListener(self, getExisting: true)
        fetchSelectedChainName()
    }
}

// MARK: - EventVisitorProtocol

extension WalletMainContainerInteractor: EventVisitorProtocol {
    func processWalletNameChanged(event: WalletNameChanged) {
        if wallet.identifier == event.wallet.identifier {
            wallet = event.wallet
            output?.didReceiveAccount(wallet)
        }
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        wallet = event.account
        output?.didReceiveAccount(event.account)
    }
}

// MARK: - ChainsIssuesCenterListener

extension WalletMainContainerInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        DispatchQueue.main.async {
            self.output?.didReceiveChainsIssues(chainsIssues: issues)
        }
    }
}
