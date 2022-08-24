import UIKit
import RobinHood

final class WalletOptionInteractor {
    // MARK: - Private properties

    private weak var output: WalletOptionInteractorOutput?
    private weak var moduleOutput: WalletOptionModuleOutput?

    private let wallet: ManagedMetaAccountModel
    private let metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    private let operationQueue: OperationQueue

    init(
        wallet: ManagedMetaAccountModel,
        metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue,
        moduleOutput: WalletOptionModuleOutput?
    ) {
        self.wallet = wallet
        self.metaAccountRepository = metaAccountRepository
        self.operationQueue = operationQueue
        self.moduleOutput = moduleOutput
    }

    // MARK: - Private methods

    private func checkDeleteButtonVisibles() {
        let operation = metaAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                return
            }
            switch result {
            case let .success(wallets):
                self?.output?.setDeleteButtonIsVisible(wallets.count > 1)
            case .failure:
                break
            }
        }

        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            output?.setDeleteButtonIsVisible(false)
            return
        }

        if selectedWallet.identifier == wallet.identifier {
            output?.setDeleteButtonIsVisible(false)
        } else {
            operationQueue.addOperation(operation)
        }
    }
}

// MARK: - WalletOptionInteractorInput

extension WalletOptionInteractor: WalletOptionInteractorInput {
    // swiftlint:disable opening_brace
    func deleteWallet() {
        let operation = metaAccountRepository.saveOperation(
            { [] },
            { [weak self] in
                guard let strongSelf = self else { return [] }
                return [strongSelf.wallet.identifier]
            }
        )

        operation.completionBlock = { [weak self] in
            self?.moduleOutput?.walletWasRemoved()
            self?.output?.walletRemoved()
        }

        operationQueue.addOperation(operation)
    }

    func setup(with output: WalletOptionInteractorOutput) {
        self.output = output
        checkDeleteButtonVisibles()
    }
}
