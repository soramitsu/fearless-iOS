import UIKit
import RobinHood

protocol BannersInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(wallet: MetaAccountModel)
}

final class BannersInteractor {
    // MARK: - Private properties

    private weak var output: BannersInteractorOutput?

    private let walletProvider: StreamableProvider<ManagedMetaAccountModel>
    private let eventCenter: EventCenterProtocol

    init(
        walletProvider: StreamableProvider<ManagedMetaAccountModel>,
        eventCenter: EventCenterProtocol
    ) {
        self.walletProvider = walletProvider
        self.eventCenter = eventCenter
    }

    // MARK: - Private methods

    private func subscribeToWallet() {
        let updateClosure: ([DataProviderChange<ManagedMetaAccountModel>]) -> Void = { [weak self] changes in
            guard let selectedWallet = changes.firstToLastChange(filter: { wallet in
                wallet.isSelected
            }) else {
                return
            }
            self?.output?.didReceive(wallet: selectedWallet.info)
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

// MARK: - BannersInteractorInput

extension BannersInteractor: BannersInteractorInput {
    func setup(with output: BannersInteractorOutput) {
        self.output = output
        subscribeToWallet()
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
}
