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

    // MARK: - Constructors

    init(
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
        self.repository = repository
        self.operationQueue = operationQueue
    }

    // MARK: - Private methods

    private func provideUserSettings() {
        do {
            guard let wallet = selectedWalletSettings.value else {
                throw ProfileInteractorError.noSelectedAccount
            }

            // TODO: Apply total account value logic instead
            let genericAddress = try wallet.substrateAccountId.toAddress(
                using: ChainFormat.substrate(42)
            )

            let userSettings = UserSettings(
                userName: wallet.name,
                details: ""
            )

            presenter?.didReceive(wallet: wallet)
        } catch {
            presenter?.didReceiveUserDataProvider(error: error)
        }
    }
}

// MARK: - ProfileInteractorInputProtocol

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup(with output: ProfileInteractorOutputProtocol) {
        presenter = output
        eventCenter.add(observer: self, dispatchIn: .main)
        provideUserSettings()
    }

    func updateWallet(_ wallet: MetaAccountModel) {
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
