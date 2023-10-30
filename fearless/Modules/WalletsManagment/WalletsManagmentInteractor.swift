import UIKit
import RobinHood

final class WalletsManagmentInteractor {
    // MARK: - Private properties

    private weak var output: WalletsManagmentInteractorOutput?

    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    private let operationQueue: OperationQueue
    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenter
    private let shouldSaveSelected: Bool
    private let featureToggleService: FeatureToggleProviderProtocol
    init(
        shouldSaveSelected: Bool,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue,
        settings: SelectedWalletSettings,
        eventCenter: EventCenter,
        featureToggleService: FeatureToggleProviderProtocol
    ) {
        self.shouldSaveSelected = shouldSaveSelected
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.metaAccountRepository = metaAccountRepository
        self.operationQueue = operationQueue
        self.settings = settings
        self.eventCenter = eventCenter
        self.featureToggleService = featureToggleService
    }

    // MARK: - Private methods

    private func fetchFeatureToggleConfig() {
        let fetchOperation = featureToggleService.fetchConfigOperation()

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.output?.didReceiveFeatureToggleConfig(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func fetchWallets() {
        let operation = metaAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                return
            }
            self?.output?.didReceiveWallets(result)
        }

        operationQueue.addOperation(operation)
    }

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletsBalances(
            deliverOn: .main,
            listener: self
        )
    }
}

// MARK: - WalletsManagmentInteractorInput

extension WalletsManagmentInteractor: WalletsManagmentInteractorInput {
    func select(wallet: ManagedMetaAccountModel) {
        guard shouldSaveSelected else {
            output?.didCompleteSelection()
            return
        }
        DispatchQueue.global().async {
            let oldMetaAccount = self.settings.value

            guard wallet.info.identifier != oldMetaAccount?.identifier else {
                DispatchQueue.main.async {
                    self.output?.didCompleteSelection()
                }
                return
            }

            self.settings.save(value: wallet.info, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case .success:
                    self?.eventCenter.notify(with: SelectedAccountChanged(account: wallet.info))
                    self?.output?.didCompleteSelection()
                case let .failure(error):
                    self?.output?.didReceive(error: error)
                }
            }
        }
    }

    func setup(with output: WalletsManagmentInteractorOutput) {
        self.output = output

        fetchWallets()
        fetchBalances()
        fetchFeatureToggleConfig()

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func fetchWalletsFromRepo() {
        fetchWallets()
    }
}

// MARK: - WalletBalanceSubscriptionHandler

extension WalletsManagmentInteractor: WalletBalanceSubscriptionListener {
    var type: WalletBalanceListenerType {
        .wallets
    }

    func handle(result: WalletBalancesResult) {
        output?.didReceiveWalletBalances(result)
    }
}

// MARK: - EventVisitorProtocol

extension WalletsManagmentInteractor: EventVisitorProtocol {
    func processWalletNameChanged(event _: WalletNameChanged) {
        fetchWallets()
    }
}
