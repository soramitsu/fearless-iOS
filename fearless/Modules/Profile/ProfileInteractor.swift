import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood

enum ProfileInteractorError: Error {
    case noSelectedAccount
}

final class ProfileInteractor {
    weak var presenter: ProfileInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let operationQueue: OperationQueue

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

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        provideUserSettings()
    }

    func updateWallet(_ wallet: MetaAccountModel) {
        selectedWalletSettings.save(value: wallet)
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async {
                self?.presenter?.didReceive(wallet: wallet)
            }
        }
    }

    func logout(completion: @escaping () -> Void) {
        let operation = repository.deleteAllOperation()
        operation.completionBlock = completion
        operationQueue.addOperation(operation)
    }
}

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
