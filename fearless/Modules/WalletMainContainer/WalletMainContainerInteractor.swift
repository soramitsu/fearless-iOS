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
        walletRecordsNoticeTracker: StoredWalletRecordsNoticeTracking
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
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        checkDeprecatedAccountIssues()
    }
}

extension WalletMainContainerInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification _: Notification) {
        checkDeprecatedAccountIssues()
    }
}
