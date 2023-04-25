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
    private let selectedMetaAccount: MetaAccountModel
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let scService: SCKYCService

    private var wallet: MetaAccountModel?
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
        scService: SCKYCService
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
        self.repository = repository
        self.operationQueue = operationQueue
        self.selectedMetaAccount = selectedMetaAccount
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.walletRepository = walletRepository
        self.scService = scService
    }

    // MARK: - Private methods

    private func provideUserSettings() {
        do {
            guard let wallet = selectedWalletSettings.value else {
                throw ProfileInteractorError.noSelectedAccount
            }

            self.wallet = wallet
            presenter?.didReceive(wallet: wallet)
        } catch {
            presenter?.didReceiveUserDataProvider(error: error)
        }
    }

    private func provideSelectedCurrency() {
        guard let currentCurrency = currentCurrency else { return }
        presenter?.didRecieve(selectedCurrency: currentCurrency)
    }

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletsBalances(
            deliverOn: .main,
            handler: self
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
    }

    func updateWallet(_ wallet: MetaAccountModel) {
        guard self.wallet?.identifier == wallet.identifier else {
            return
        }
        selectedWalletSettings.save(value: wallet)
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceive(wallet: wallet)
        }
    }

    func logout(completion: @escaping () -> Void) {
        let operation = repository.deleteAllOperation()
        operation.completionBlock = completion
        operationQueue.addOperation(operation)
    }

    func update(currency: Currency) {
        currentCurrency = currency
        provideSelectedCurrency()
    }

    func update(zeroBalanceAssetsHidden: Bool) {
        let updatedWallet = selectedMetaAccount.replacingZeroBalanceAssetsHidden(zeroBalanceAssetsHidden)

        let saveOperation = walletRepository.saveOperation {
            [updatedWallet]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            let event = MetaAccountModelChangedEvent(account: updatedWallet)
            self?.eventCenter.notify(with: event)

            DispatchQueue.main.async {
                self?.presenter?.didReceive(wallet: updatedWallet)
            }
        }

        operationQueue.addOperation(saveOperation)
    }

    func prepareStartSoraCard() async {
        if await SCStorage.shared.token() != nil {
            let response = await scService.kycStatuses()

            switch response {
            case let .success(statuses):
                await MainActor.run { [weak self] in
                    self?.presenter?.didReceive(kycStatuses: statuses)
                }
            case let .failure(error):
                await MainActor.run { [weak self] in
                    self?.presenter?.didReceive(error: error)
                }
                SCTokenHolder.shared.removeToken()
                await MainActor.run { [weak self] in
                    self?.presenter?.restartKYC()
                }
            }
        } else {
            await MainActor.run { [weak self] in
                self?.presenter?.restartKYC()
            }
        }
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

extension ProfileInteractor: WalletBalanceSubscriptionHandler {
    func handle(result: WalletBalancesResult) {
        presenter?.didReceiveWalletBalances(result)
    }
}
