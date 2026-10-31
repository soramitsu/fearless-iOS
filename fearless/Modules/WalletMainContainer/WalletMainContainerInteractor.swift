import UIKit
import RobinHood
import SSFModels
import SoraFoundation

final class WalletMainContainerInteractor {
    // MARK: - Private properties

    private weak var output: WalletMainContainerInteractorOutput?

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private var wallet: MetaAccountModel
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol
    private let deprecatedAccountsCheckService: DeprecatedControllerStashAccountCheckServiceProtocol
    private let applicationHandler: ApplicationHandler
    private let walletConnectService: WalletConnectService
    private let featureToggleService: FeatureToggleProviderProtocol
    private let walletRecordsInspector: StoredWalletRecordsInspecting
    private let walletRecordsNoticeTracker: StoredWalletRecordsNoticeTracking
    private var walletRecordsReport: StoredWalletRecordsReport?
    private let passwordSwitcher: UniversalWalletPasswordSwitcher
    private let passwordNoticeTracker: UniversalWalletPasswordNoticeTracker
    private let watchedAccounts: UniversalWalletWatchedAccountsStore
    private let watchedAccountsChecker: UniversalWalletWatchedAccountsChecker
    private var isCheckingWatchedAccounts = false
    private var portfolioRefreshObserver: NSObjectProtocol?

    // MARK: - Constructor

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        wallet: MetaAccountModel,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        deprecatedAccountsCheckService: DeprecatedControllerStashAccountCheckServiceProtocol,
        applicationHandler: ApplicationHandler,
        walletConnectService: WalletConnectService,
        featureToggleService: FeatureToggleProviderProtocol,
        walletRecordsInspector: StoredWalletRecordsInspecting,
        walletRecordsNoticeTracker: StoredWalletRecordsNoticeTracking,
        passwordSwitcher: UniversalWalletPasswordSwitcher = UniversalWalletPasswordSwitcher(),
        passwordNoticeTracker: UniversalWalletPasswordNoticeTracker = UniversalWalletPasswordNoticeTracker(),
        watchedAccounts: UniversalWalletWatchedAccountsStore = UniversalWalletWatchedAccountsStore(),
        watchedAccountsChecker: UniversalWalletWatchedAccountsChecker = UniversalWalletWatchedAccountsChecker()
    ) {
        self.wallet = wallet
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.deprecatedAccountsCheckService = deprecatedAccountsCheckService
        self.applicationHandler = applicationHandler
        self.walletConnectService = walletConnectService
        self.featureToggleService = featureToggleService
        self.walletRecordsInspector = walletRecordsInspector
        self.walletRecordsNoticeTracker = walletRecordsNoticeTracker
        self.passwordSwitcher = passwordSwitcher
        self.passwordNoticeTracker = passwordNoticeTracker
        self.watchedAccounts = watchedAccounts
        self.watchedAccountsChecker = watchedAccountsChecker
        applicationHandler.delegate = self
    }

    // MARK: - Private method

    private func fetchNetworkManagmentFilter() {
        guard let identifier = wallet.networkManagmentFilter else {
            output?.didReceiveSelected(tuple: (select: .all, chains: []))
            return
        }

        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                self?.output?.didReceiveError(BaseOperationError.unexpectedDependentResult)
                return
            }

            switch result {
            case let .success(chains):
                self?.output?.didReceiveSelected(tuple: (select: NetworkManagmentFilter(identifier: identifier), chains))
            case let .failure(error):
                self?.output?.didReceiveError(error)
            }
        }

        operationQueue.addOperation(operation)
    }

    private func checkDeprecatedAccountIssues() {
        Task {
            if let issue = try? await deprecatedAccountsCheckService.checkAccountDeprecations(wallet: wallet) {
                switch issue {
                case let .controller(issue):
                    let stashItem = try? await self.deprecatedAccountsCheckService.checkStashItems().first
                    await MainActor.run {
                        self.output?.didReceiveControllerAccountIssue(issue: issue, hasStashItem: stashItem != nil)
                    }
                case let .stash(address):
                    await MainActor.run {
                        self.output?.didReceiveStashAccountIssue(address: address)
                    }
                }
            }
        }
    }

    /// Tells the user once about stored wallets or accounts the app does not show or use,
    /// so nothing stored goes missing without a word after an update.
    private func checkStoredWalletRecords() {
        let reportOperation = walletRecordsInspector.fetchReportOperation()

        reportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard
                    let self,
                    let report = try? reportOperation.extractNoCancellableResultData()
                else {
                    return
                }

                self.walletRecordsReport = report
                let notices = self.walletRecordsNoticeTracker.pendingNotices(for: report)
                if !notices.isEmpty {
                    self.output?.didReceiveStoredWalletRecordsNotices(notices)
                }
            }
        }

        operationQueue.addOperation(reportOperation)
    }

    /// Shows once per wallet that its password does not protect some universal accounts yet.
    private func checkUniversalWalletPassword() {
        let wallet = self.wallet
        guard !passwordNoticeTracker.wasShown(for: wallet.metaId) else {
            return
        }
        let switcher = passwordSwitcher
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let accounts = switcher.noPasswordAccounts(in: wallet)
            DispatchQueue.main.async {
                guard let self, !accounts.isEmpty, self.wallet.metaId == wallet.metaId else {
                    return
                }
                self.output?.didReceiveUniversalWalletNoPasswordAccounts(accounts)
            }
        }
    }

    /// Old addresses a password wallet left stay watched: funds there bring the address back
    /// when its password-protected account is empty, and are reported otherwise.
    private func checkWatchedOldAddresses() {
        guard !isCheckingWatchedAccounts else { return }
        isCheckingWatchedAccounts = true
        let wallet = self.wallet
        let checker = watchedAccountsChecker
        Task { [weak self] in
            let result = await checker.check(wallet)
            await MainActor.run {
                guard let self else { return }
                self.isCheckingWatchedAccounts = false
                self.apply(result, checkedFrom: wallet)
            }
        }
    }

    private func apply(_ result: UniversalWalletWatchedAccountsChecker.Result, checkedFrom wallet: MetaAccountModel) {
        let arrivals = watchedAccounts.unnotified(result.arrivals, in: wallet.metaId)
        if !arrivals.isEmpty {
            output?.didReceiveUniversalWalletOldAddressArrivals(arrivals)
        }
        guard !result.movedBack.isEmpty, result.wallet != wallet else { return }
        // A newer change to the wallet wins; the next check sees the funds again.
        SelectedWalletSettings.shared.save(
            value: result.wallet,
            ifCurrentValueSatisfies: { $0 == wallet },
            runningCompletionIn: .main,
            completionClosure: { [weak self] saveResult in
                guard case let .success(savedWallet) = saveResult else { return }
                Task { @MainActor [weak self] in
                    await BitcoinWalletBalanceCache.shared.invalidate(walletId: savedWallet.metaId)
                    self?.passwordNoticeTracker.reset(for: savedWallet.metaId)
                    self?.eventCenter.notify(with: SelectedAccountChanged(account: savedWallet))
                }
            }
        )
    }

    private func checkNftAvailability() {
        let fetchOperation = featureToggleService.fetchConfigOperation()

        fetchOperation.completionBlock = {
            let config = try? fetchOperation.extractNoCancellableResultData()

            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceiveNftAvailability(isNftAvailable: config?.nftEnabled == true)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }
}

// MARK: - WalletMainContainerInteractorInput

extension WalletMainContainerInteractor: WalletMainContainerInteractorInput {
    func setup(with output: WalletMainContainerInteractorOutput) {
        self.output = output
        eventCenter.add(observer: self, dispatchIn: .main)
        fetchNetworkManagmentFilter()
        checkNftAvailability()
        checkStoredWalletRecords()
        checkUniversalWalletPassword()
        checkWatchedOldAddresses()
        portfolioRefreshObserver = NotificationCenter.default.addObserver(
            forName: .universalWalletPortfolioRefreshed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkWatchedOldAddresses()
        }
    }

    func walletConnect(uri: String) async throws {
        try await walletConnectService.connect(uri: uri)
    }

    func acknowledge(_ notice: StoredWalletRecordsNotice) {
        guard let report = walletRecordsReport else {
            return
        }

        switch notice {
        case .recordsNotShown:
            walletRecordsNoticeTracker.acknowledgeRecordsNotShown(in: report)
        case .storedChainAccounts:
            walletRecordsNoticeTracker.acknowledgeStoredChainAccounts(in: report)
        }
    }

    func acknowledgeUniversalWalletPasswordNotice() {
        passwordNoticeTracker.markShown(for: wallet.metaId)
    }

    func acknowledgeOldAddressArrivals(_ arrivals: [UniversalWalletOldAddressArrival]) {
        watchedAccounts.markNotified(arrivals, in: wallet.metaId)
    }

    /// Replaces the old accounts that hold nothing and saves the wallet only if nothing
    /// changed it in the meantime.
    func switchNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount]) {
        let wallet = self.wallet
        let switcher = passwordSwitcher
        Task { [weak self] in
            let result = await switcher.switching(accounts, in: wallet)
            await MainActor.run {
                guard let self else { return }
                guard result.wallet != wallet else {
                    self.output?.didReceiveUniversalWalletSwitchOutcomes(result.outcomes, for: accounts)
                    return
                }
                let accepted = SelectedWalletSettings.shared.save(
                    value: result.wallet,
                    ifCurrentValueSatisfies: { $0 == wallet },
                    runningCompletionIn: .main,
                    completionClosure: { [weak self] saveResult in
                        switch saveResult {
                        case let .success(savedWallet):
                            Task { @MainActor [weak self] in
                                await BitcoinWalletBalanceCache.shared.invalidate(walletId: savedWallet.metaId)
                                self?.eventCenter.notify(with: SelectedAccountChanged(account: savedWallet))
                                self?.output?.didReceiveUniversalWalletSwitchOutcomes(result.outcomes, for: accounts)
                            }
                        case let .failure(error):
                            self?.output?.didReceiveError(error)
                        }
                    }
                )
                if !accepted {
                    // Another change to the wallet came first; nothing was switched.
                    self.output?.didReceiveUniversalWalletSwitchOutcomes(
                        result.outcomes.mapValues { $0 == .switched ? .unchecked : $0 },
                        for: accounts
                    )
                }
            }
        }
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
        if wallet.networkManagmentFilter != event.account.networkManagmentFilter {
            wallet = event.account
            fetchNetworkManagmentFilter()
        }
        wallet = event.account
        output?.didReceiveAccount(event.account)
    }

    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return
        }

        self.wallet = wallet
        output?.didReceiveAccount(wallet)

        fetchNetworkManagmentFilter()
        checkUniversalWalletPassword()
        checkWatchedOldAddresses()
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        checkDeprecatedAccountIssues()
    }
}

extension WalletMainContainerInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification _: Notification) {
        checkDeprecatedAccountIssues()
        checkWatchedOldAddresses()
    }
}
