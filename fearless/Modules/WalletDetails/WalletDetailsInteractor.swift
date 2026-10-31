import RobinHood
import SSFModels
import Foundation

final class WalletDetailsInteractor {
    weak var presenter: WalletDetailsInteractorOutputProtocol!

    private var flow: WalletDetailsFlow {
        didSet {
            presenter.didReceive(updatedFlow: flow)
        }
    }

    private let chainsRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    private let walletRecordsInspector: StoredWalletRecordsInspecting
    private let walletRecordsNoticeTracker: StoredWalletRecordsNoticeTracking
    private let selectedWalletSettings: SelectedWalletSettings
    private let passwordSwitcher: UniversalWalletPasswordSwitcher

    init(
        flow: WalletDetailsFlow,
        chainsRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        walletRecordsInspector: StoredWalletRecordsInspecting,
        walletRecordsNoticeTracker: StoredWalletRecordsNoticeTracking,
        selectedWalletSettings: SelectedWalletSettings,
        passwordSwitcher: UniversalWalletPasswordSwitcher = UniversalWalletPasswordSwitcher()
    ) {
        self.flow = flow
        self.chainsRepository = chainsRepository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.repository = repository
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.walletRecordsInspector = walletRecordsInspector
        self.walletRecordsNoticeTracker = walletRecordsNoticeTracker
        self.selectedWalletSettings = selectedWalletSettings
        self.passwordSwitcher = passwordSwitcher
        self.eventCenter.add(observer: self)
    }
}

extension WalletDetailsInteractor: AccountFetching {}

extension WalletDetailsInteractor: WalletDetailsInteractorInputProtocol {
    func markUnused(chain: ChainModel) {
        var unusedChainIds = flow.wallet.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = flow.wallet.replacingUnusedChainIds(unusedChainIds)

        let saveOperation = repository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    DispatchQueue.main.async {
                        if case .normal = self?.flow {
                            self?.flow = .normal(wallet: account)
                        }

                        self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                    }

                case .failure:
                    break
                }
            }
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    func setup() {
        switch flow {
        case .normal:
            fetchChainsWithAccounts()
            fetchStoredChainAccounts(acknowledging: false)
            fetchNoPasswordAccounts()
        case let .export(_, accounts):
            presenter.didReceive(chains: accounts.map(\.chain))
        }
    }

    func selectChainAccount(_ selection: ChainAccountSelection, chain: ChainModel) {
        let walletId = flow.wallet.metaId
        let selectOperation = walletRecordsInspector.selectChainAccountOperation(
            ChainAccountSelectionUpdate(chainId: chain.chainId, selection: selection),
            walletId: walletId
        )

        selectOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let wallet = try selectOperation.extractNoCancellableResultData()
                    self?.didSelectChainAccount(in: wallet)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [selectOperation], in: .transient)
    }

    func getAvailableExportOptions(for chainAccount: ChainAccountInfo) {
        guard let address = chainAccount.account.toAddress() else {
            presenter.didReceive(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        fetchChainAccountFor(
            meta: flow.wallet,
            chain: chainAccount.chain,
            address: address
        ) { [weak self] result in
            switch result {
            case let .success(chainResponse):
                guard let self = self, let response = chainResponse else {
                    self?.presenter?.didReceiveExportOptions(options: [.keystore], for: chainAccount)
                    return
                }
                let accountId = response.isChainAccount ? response.accountId : nil
                let options = self.availableExportOptionsProvider
                    .getAvailableExportOptions(
                        for: self.flow.wallet,
                        accountId: accountId,
                        isEthereum: response.isEthereumBased
                    )
                self.presenter?.didReceiveExportOptions(options: options, for: chainAccount)
            default:
                self?.presenter?.didReceiveExportOptions(options: [.keystore], for: chainAccount)
            }
        }
    }
}

extension WalletDetailsInteractor {
    func switchToPasswordAccount(_ account: UniversalWalletNoPasswordAccount) {
        let wallet = flow.wallet
        let switcher = passwordSwitcher
        Task { [weak self] in
            let result = await switcher.switching([account], in: wallet)
            await MainActor.run {
                self?.saveSwitchedWallet(result.wallet, replacing: wallet, outcomes: result.outcomes, for: [account])
            }
        }
    }
}

private extension WalletDetailsInteractor {
    func fetchNoPasswordAccounts() {
        let wallet = flow.wallet
        let switcher = passwordSwitcher
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let accounts = switcher.noPasswordAccounts(in: wallet)
            DispatchQueue.main.async {
                self?.presenter.didReceive(noPasswordAccounts: accounts)
            }
        }
    }

    /// Saves only over the wallet the switch was computed from.
    func saveSwitchedWallet(
        _ updated: MetaAccountModel,
        replacing original: MetaAccountModel,
        outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount]
    ) {
        guard updated != original else {
            presenter.didReceive(switchOutcomes: outcomes, for: accounts)
            return
        }
        let notSaved = outcomes.mapValues { $0 == .switched ? UniversalWalletSwitchOutcome.unchecked : $0 }

        guard selectedWalletSettings.value?.metaId == original.metaId else {
            let saveOperation = repository.saveOperation({ [updated] }, { [] })
            saveOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard case .success = saveOperation.result else {
                        self.presenter.didReceive(switchOutcomes: notSaved, for: accounts)
                        return
                    }
                    self.didSwitch(to: updated, outcomes: outcomes, for: accounts)
                    self.announceSwitch(of: updated, with: MetaAccountModelChangedEvent(account: updated))
                }
            }
            operationManager.enqueue(operations: [saveOperation], in: .transient)
            return
        }

        let accepted = selectedWalletSettings.save(
            value: updated,
            ifCurrentValueSatisfies: { $0 == original },
            runningCompletionIn: .main,
            completionClosure: { [weak self] result in
                switch result {
                case let .success(savedWallet):
                    self?.didSwitch(to: savedWallet, outcomes: outcomes, for: accounts)
                    self?.announceSwitch(of: savedWallet, with: SelectedAccountChanged(account: savedWallet))
                case let .failure(error):
                    self?.presenter.didReceive(error: error)
                }
            }
        )
        if !accepted {
            presenter.didReceive(switchOutcomes: notSaved, for: accounts)
        }
    }

    func didSwitch(
        to wallet: MetaAccountModel,
        outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount]
    ) {
        if case .normal = flow {
            flow = .normal(wallet: wallet)
        }
        fetchNoPasswordAccounts()
        presenter.didReceive(switchOutcomes: outcomes, for: accounts)
    }

    /// Drops scans of the old Bitcoin account before anything reads the switched wallet.
    func announceSwitch(of wallet: MetaAccountModel, with event: EventProtocol) {
        Task { @MainActor [weak self] in
            await BitcoinWalletBalanceCache.shared.invalidate(walletId: wallet.metaId)
            self?.eventCenter.notify(with: event)
        }
    }

    /// The store already holds the switch. Hand the wallet as stored to everything that
    /// shows its addresses or balances.
    func didSelectChainAccount(in wallet: MetaAccountModel) {
        if case .normal = flow {
            flow = .normal(wallet: wallet)
        }
        // The user made this switch here, so there is nothing left to announce about it.
        fetchStoredChainAccounts(acknowledging: true)

        guard selectedWalletSettings.value?.metaId == wallet.metaId else {
            eventCenter.notify(with: MetaAccountModelChangedEvent(account: wallet))
            return
        }

        selectedWalletSettings.save(value: wallet, runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(savedWallet):
                self?.eventCenter.notify(with: SelectedAccountChanged(account: savedWallet))
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }

    func fetchStoredChainAccounts(acknowledging: Bool) {
        let walletId = flow.wallet.metaId
        let reportOperation = walletRecordsInspector.fetchReportOperation()

        reportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let report = try? reportOperation.extractNoCancellableResultData() else {
                    return
                }
                if acknowledging {
                    self?.walletRecordsNoticeTracker.acknowledgeStoredChainAccounts(of: walletId, in: report)
                }
                self?.presenter.didReceive(storedChainAccounts: report.alternatives(for: walletId))
            }
        }

        operationManager.enqueue(operations: [reportOperation], in: .transient)
    }

    func fetchChainsWithAccounts() {
        let fetchOperation = chainsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            presenter.didReceive(chains: chains)
        case .failure, .none:
            return
        }
    }
}

extension WalletDetailsInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if case .normal = flow {
            DispatchQueue.main.async {
                self.flow = .normal(wallet: event.account)
            }
        }
    }
}
