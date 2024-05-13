import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood

enum ProfileInteractorError: Error {
    case noSelectedAccount
}

final class ProfileInteractor {
    // MARK: - Private properties

    private weak var presenter: ProfileInteractorOutputProtocol?
    private let selectedWalletSettings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol
    private let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    private let operationQueue: OperationQueue
    private var selectedMetaAccount: MetaAccountModel
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainsIssuesCenter: ChainsIssuesCenterProtocol
    private let walletConnectDisconnectService: WalletConnectDisconnectService

    private lazy var currentCurrency: Currency? = {
        selectedMetaAccount.selectedCurrency
    }()

    // MARK: - Constructors

    init(
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue,
        selectedMetaAccount: MetaAccountModel,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainsIssuesCenter: ChainsIssuesCenterProtocol,
        walletConnectDisconnectService: WalletConnectDisconnectService
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
        self.repository = repository
        self.operationQueue = operationQueue
        self.selectedMetaAccount = selectedMetaAccount
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.walletRepository = walletRepository
        self.chainsIssuesCenter = chainsIssuesCenter
        self.walletConnectDisconnectService = walletConnectDisconnectService
    }

    // MARK: - Private methods

    private func provideUserSettings() {
        do {
            guard let wallet = selectedWalletSettings.value else {
                throw ProfileInteractorError.noSelectedAccount
            }

            presenter?.didReceive(wallet: wallet)
            selectedMetaAccount = wallet
            fetchBalances()
        } catch {
            presenter?.didReceiveUserDataProvider(error: error)
        }
    }

    private func provideSelectedCurrency() {
        guard let currentCurrency = currentCurrency else { return }
        presenter?.didRecieve(selectedCurrency: currentCurrency)
    }

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletBalance(
            wallet: selectedMetaAccount,
            listener: self
        )
    }
}

// MARK: - ProfileInteractorInputProtocol

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup(with output: ProfileInteractorOutputProtocol) {
        presenter = output
        eventCenter.add(observer: self, dispatchIn: .main)
        provideUserSettings()
        provideSelectedCurrency()
        fetchBalances()
        chainsIssuesCenter.addIssuesListener(self, getExisting: true)
    }

    func updateWallet(_ wallet: MetaAccountModel) {
        guard selectedMetaAccount.identifier == wallet.identifier else {
            return
        }
        selectedWalletSettings.save(value: wallet)
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceive(wallet: wallet)
        }
    }

    func logout(completion: @escaping () -> Void) {
        let operation = repository.deleteAllOperation()
        operation.completionBlock = { [weak self] in
            self?.walletConnectDisconnectService.disconnectAllSessions()
            completion()
        }
        operationQueue.addOperation(operation)
    }

    func update(currency: Currency) {
        currentCurrency = currency
        provideSelectedCurrency()
    }
}

// MARK: - EventVisitorProtocol

extension ProfileInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideUserSettings()
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        provideUserSettings()
    }

    func processWalletNameChanged(event: WalletNameChanged) {
        updateWallet(event.wallet)
    }
}

extension ProfileInteractor: WalletBalanceSubscriptionListener {
    var type: WalletBalanceListenerType {
        .wallet(wallet: selectedMetaAccount)
    }

    func handle(result: WalletBalancesResult) {
        presenter?.didReceiveWalletBalances(result)
    }
}

extension ProfileInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        let missingAccountIssues = issues.filter { issue in
            switch issue {
            case .missingAccount:
                return true
            default: return false
            }
        }
        presenter?.didReceiveMissingAccount(issues: missingAccountIssues)
    }
}
