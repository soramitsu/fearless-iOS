import UIKit
import RobinHood

final class WalletOptionInteractor {
    // MARK: - Private properties

    private weak var output: WalletOptionInteractorOutput?
    private weak var moduleOutput: WalletOptionModuleOutput?

    private let wallet: ManagedMetaAccountModel
    private let metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    private let operationQueue: OperationQueue
    private let walletConnectDisconnectService: WalletConnectDisconnectService
    private let secretEraser: WalletSecretEraser

    init(
        wallet: ManagedMetaAccountModel,
        metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue,
        moduleOutput: WalletOptionModuleOutput?,
        walletConnectDisconnectService: WalletConnectDisconnectService,
        secretEraser: WalletSecretEraser = WalletSecretEraser()
    ) {
        self.wallet = wallet
        self.metaAccountRepository = metaAccountRepository
        self.operationQueue = operationQueue
        self.moduleOutput = moduleOutput
        self.walletConnectDisconnectService = walletConnectDisconnectService
        self.secretEraser = secretEraser
    }

    // MARK: - Private methods

    private func checkDeleteButtonVisibles() {
        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            output?.setDeleteButtonIsVisible(false)
            return
        }

        if selectedWallet.identifier == wallet.identifier {
            output?.setDeleteButtonIsVisible(false)
        }
    }
}

// MARK: - WalletOptionInteractorInput

extension WalletOptionInteractor: WalletOptionInteractorInput {
    func deleteWallet() {
        Task { [weak self] in
            guard let self else { return }
            // Perform deletion by identifier; ignore errors to match prior behavior.
            if (try? await metaAccountRepository.saveAsync(insert: [], deleteIds: [wallet.identifier])) != nil {
                // Watched old addresses go only with their wallet.
                UniversalWalletWatchedAccountsStore().forget(walletId: wallet.info.metaId)
                // The user asked to forget this wallet: its secrets go too. Keys are removed
                // only after the row is gone, so a failure can never leave a keyless wallet.
                let remaining = (try? await metaAccountRepository.fetchAllAsync()) ?? []
                secretEraser.eraseSecrets(
                    of: [wallet.info],
                    remainingMetaIds: Set(remaining.map(\.info.metaId))
                )
            }
            // Disconnect WC sessions if any; errors are non-fatal for UX here.
            try? await walletConnectDisconnectService.disconnect(wallet: wallet.info)
            await MainActor.run { [weak self] in
                self?.moduleOutput?.walletWasRemoved()
                self?.output?.walletRemoved()
            }
        }
    }

    func setup(with output: WalletOptionInteractorOutput) {
        self.output = output
        checkDeleteButtonVisibles()
    }
}
