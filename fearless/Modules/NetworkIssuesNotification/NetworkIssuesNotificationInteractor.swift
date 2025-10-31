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
        Task { [weak self] in
            guard let self else { return }
            // Save updated account
            try? await accountRepository.saveAsync(insert: [updatedAccount], delete: [])
            // Persist in SelectedWalletSettings and notify on main
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(wallet):
                    DispatchQueue.main.async { [weak self] in
                        self?.wallet = wallet
                        self?.output?.didReceiveWallet(wallet: wallet)
                        self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: wallet))
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func save(chainSettings: ChainSettings) {
        Task { [weak self] in
            guard let self else { return }
            try? await chainSettingsRepository.saveAsync(insert: [chainSettings], delete: [])
            await MainActor.run { [weak self] in
                self?.fetchChainSettings()
                self?.chainsIssuesCenter.forceNotify()
            }
        }
    }

    private func fetchChainSettings() {
        Task { [weak self] in
            guard let self else { return }
            let settings: [ChainSettings]
            do {
                settings = try await chainSettingsRepository.fetchAllAsync()
            } catch {
                settings = []
            }
            await MainActor.run { [weak self] in
                self?.output?.didReceive(chainSettings: settings)
            }
        }
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
        Task { [weak self] in
            guard let self else { return }
            var chainSettings = (try? await chainSettingsRepository.fetchAsync(by: chain.chainId)) ?? ChainSettings.defaultSettings(for: chain.chainId)
            chainSettings.setIssueMuted(true)
            self.save(chainSettings: chainSettings)
        }
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
