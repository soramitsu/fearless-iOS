import UIKit
import RobinHood
import SSFModels

final class NetworkIssuesNotificationInteractor {
    // MARK: - Private properties

    private weak var output: NetworkIssuesNotificationInteractorOutput?

    private var wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenter
    private let chainsIssuesCenter: ChainsIssuesCenterProtocol
    private let chainSettingsRepository: AnyDataProviderRepository<ChainSettings>

    init(
        wallet: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        eventCenter: EventCenter,
        chainsIssuesCenter: ChainsIssuesCenterProtocol,
        chainSettingsRepository: AnyDataProviderRepository<ChainSettings>
    ) {
        self.wallet = wallet
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.chainsIssuesCenter = chainsIssuesCenter
        self.chainSettingsRepository = chainSettingsRepository
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

    private func save(chainSettings: ChainSettings) {
        let saveOperation = chainSettingsRepository.saveOperation {
            [chainSettings]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            self?.fetchChainSettings()

            self?.chainsIssuesCenter.forceNotify()
        }

        operationQueue.addOperation(saveOperation)
    }

    private func fetchChainSettings() {
        let fetchChainSettingsOperation = chainSettingsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchChainSettingsOperation.completionBlock = { [weak self] in
            let chainSettings = (try? fetchChainSettingsOperation.extractNoCancellableResultData()) ?? []
            DispatchQueue.main.async {
                self?.output?.didReceive(chainSettings: chainSettings)
            }
        }

        operationQueue.addOperation(fetchChainSettingsOperation)
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

    func mute(chain: ChainModel) {
        let fetchChainSettingsOperation = chainSettingsRepository.fetchOperation(by: {
            chain.chainId
        }, options: RepositoryFetchOptions())

        fetchChainSettingsOperation.completionBlock = { [weak self] in
            var chainSettings = (try? fetchChainSettingsOperation.extractNoCancellableResultData()) ?? ChainSettings.defaultSettings(for: chain.chainId)

            chainSettings.setIssueMuted(true)
            self?.save(chainSettings: chainSettings)
            self?.eventCenter.notify(with: ChainsSettingsChanged())
        }

        operationQueue.addOperation(fetchChainSettingsOperation)
    }

    func setup(with output: NetworkIssuesNotificationInteractorOutput) {
        self.output = output
        fetchChainSettings()
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
