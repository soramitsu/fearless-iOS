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
    private let chainsIssuesCenter: ChainsIssuesCenter
    private let chainSettingsRepository: AnyDataProviderRepository<ChainSettings>
    private let deprecatedAccountsCheckService: DeprecatedControllerStashAccountCheckServiceProtocol
    private let applicationHandler: ApplicationHandler
    private let walletConnectService: WalletConnectService

    // MARK: - Constructor

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        wallet: MetaAccountModel,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        chainsIssuesCenter: ChainsIssuesCenter,
        chainSettingsRepository: AnyDataProviderRepository<ChainSettings>,
        deprecatedAccountsCheckService: DeprecatedControllerStashAccountCheckServiceProtocol,
        applicationHandler: ApplicationHandler,
        walletConnectService: WalletConnectService
    ) {
        self.wallet = wallet
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.chainsIssuesCenter = chainsIssuesCenter
        self.chainSettingsRepository = chainSettingsRepository
        self.deprecatedAccountsCheckService = deprecatedAccountsCheckService
        self.applicationHandler = applicationHandler
        self.walletConnectService = walletConnectService
        applicationHandler.delegate = self
    }

    // MARK: - Private methods

    private func fetchNetworkManagmentFilter() {
        guard let identifier = wallet.networkManagmentFilter else {
            DispatchQueue.main.async {
                self.output?.didReceiveSelected(tuple: (select: .all, chains: []))
            }
            return
        }

        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                DispatchQueue.main.async {
                    self?.output?.didReceiveError(BaseOperationError.unexpectedDependentResult)
                }
                return
            }

            switch result {
            case let .success(chains):
                DispatchQueue.main.async {
                    self?.output?.didReceiveSelected(tuple: (select: NetworkManagmentFilter(identifier: identifier), chains))
                }
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
                    self?.wallet = account
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                    self?.fetchNetworkManagmentFilter()
                case .failure:
                    break
                }
            }
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
}

// MARK: - WalletMainContainerInteractorInput

extension WalletMainContainerInteractor: WalletMainContainerInteractorInput {
    func saveNetworkManagment(_ select: NetworkManagmentFilter) {
        var updatedAccount: MetaAccountModel?

        if select.identifier != wallet.networkManagmentFilter {
            updatedAccount = wallet.replacingNetworkManagmentFilter(select.identifier)
        }

        if let updatedAccount = updatedAccount {
            save(updatedAccount)
        }
    }

    func setup(with output: WalletMainContainerInteractorOutput) {
        self.output = output
        eventCenter.add(observer: self, dispatchIn: .main)
        chainsIssuesCenter.addIssuesListener(self, getExisting: true)
        fetchNetworkManagmentFilter()
        fetchChainSettings()
    }

    func walletConnect(uri: String) async throws {
        try await walletConnectService.connect(uri: uri)
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

// MARK: - ChainsIssuesCenterListener

extension WalletMainContainerInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        DispatchQueue.main.async {
            self.output?.didReceiveChainsIssues(chainsIssues: issues)
        }
    }
}

extension WalletMainContainerInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification _: Notification) {
        checkDeprecatedAccountIssues()
    }
}
