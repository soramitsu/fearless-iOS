import UIKit
import RobinHood

final class NetworkIssuesNotificationInteractor {
    // MARK: - Private properties

    private weak var output: NetworkIssuesNotificationInteractorOutput?

    private var wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenter
    private let chainsIssuesCenter: ChainsIssuesCenter

    init(
        wallet: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        eventCenter: EventCenter,
        chainsIssuesCenter: ChainsIssuesCenter
    ) {
        self.wallet = wallet
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.chainsIssuesCenter = chainsIssuesCenter
    }

    // MARK: - Private methods

    private func save(_ updatedAccount: MetaAccountModel) {
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(wallet):
                    DispatchQueue.main.async {
                        self?.wallet = wallet
                        self?.output?.didReceiveWallet(wallet: wallet)
                        self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: wallet))
                    }
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}

// MARK: - NetworkIssuesNotificationInteractorInput

extension NetworkIssuesNotificationInteractor: NetworkIssuesNotificationInteractorInput {
    func markUnused(chain: ChainModel) {
        var unusedChainIds = wallet.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = wallet.replacingUnusedChainIds(unusedChainIds)

        save(updatedAccount)
    }

    func setup(with output: NetworkIssuesNotificationInteractorOutput) {
        self.output = output

        chainsIssuesCenter.addIssuesListener(self, getExisting: true)
    }
}

extension NetworkIssuesNotificationInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        DispatchQueue.main.async {
            self.output?.didReceiveChainsIssues(issues: issues)
        }
    }
}
