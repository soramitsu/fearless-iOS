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
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let operationQueue: OperationQueue

    init(
        walletProvider: StreamableProvider<ManagedMetaAccountModel>,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.walletProvider = walletProvider
        self.repository = repository
        self.operationQueue = operationQueue
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

        let operation = repository.saveOperation {
            [updatedWallet]
        } _: {
            []
        }

        operation.completionBlock = {
            SelectedWalletSettings.shared.performSave(value: updatedWallet) { [weak self] result in
                switch result {
                case let .success(account):
                    self?.output?.didReceive(wallet: account)
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(operation)
    }
}
