import UIKit
import SoraKeystore
import RobinHood
import SSFModels

protocol BannersInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(wallet: MetaAccountModel)
}

final class BannersInteractor {
    // MARK: - Private properties

    private weak var output: BannersInteractorOutput?

    private let walletProvider: StreamableProvider<ManagedMetaAccountModel>
    private let eventCenter: EventCenterProtocol
    private let userDefaults: SettingsManagerProtocol

    init(
        walletProvider: StreamableProvider<ManagedMetaAccountModel>,
        eventCenter: EventCenterProtocol,
        userDefaults: SettingsManagerProtocol
    ) {
        self.walletProvider = walletProvider
        self.eventCenter = eventCenter
        self.userDefaults = userDefaults
    }

    // MARK: - Private methods
}

// MARK: - BannersInteractorInput

extension BannersInteractor: BannersInteractorInput {
    var shouldShowAddWalletBanner: Bool {
        get {
            userDefaults.shouldShowAddWalletBanner
        }
        set {
            userDefaults.shouldShowAddWalletBanner = newValue
        }
    }

    func setup(with output: BannersInteractorOutput) {
        self.output = output
    }

    func markWalletAsBackedUp(_ wallet: MetaAccountModel) {
        let updatedWallet = wallet.replacingIsBackuped(true)

        SelectedWalletSettings.shared.performSave(value: updatedWallet) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .success(account):
                    self?.output?.didReceive(wallet: account)
                    let event = MetaAccountModelChangedEvent(account: account)
                    self?.eventCenter.notify(with: event)
                case let .failure(error):
                    self?.output?.didReceive(error: error)
                }
            }
        }
    }

    func subscribeToWallet() {
        let updateClosure: ([DataProviderChange<ManagedMetaAccountModel>]) -> Void = { [weak self] changes in
            guard let wallet = changes.reduceToLastChange() else {
                return
            }
            self?.output?.didReceive(wallet: wallet.info)
            changes.forEach { change in
                switch change {
                case let .insert(newItem: newItem):
                    self?.output?.didReceive(wallet: newItem.info)
                case let .update(newItem: newItem):
                    self?.output?.didReceive(wallet: newItem.info)
                case let .delete(deletedIdentifier: deletedIdentifier):
                    break
                }
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.output?.didReceive(error: error)
        }

        let options = StreamableProviderObserverOptions()

        walletProvider.addObserver(
            self,
            deliverOn: .global(),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}
