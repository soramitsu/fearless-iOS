import UIKit
import RobinHood
import SSFModels
import SSFCloudStorage
import IrohaCrypto
import SoraKeystore

protocol BackupWalletInteractorOutput: AnyObject {
    func didReceiveBalances(result: WalletBalancesResult)
    func didReceive(chains: [ChainModel])
    func didReceive(options: [ExportOption])
    func didReceive(error: Error)
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>)
    func didReceiveRemove(result: Result<Void, Error>)
}

final class BackupWalletInteractor {
    var cloudStorage: FearlessCompatibilityProtocol?

    // MARK: - Private properties

    private weak var output: BackupWalletInteractorOutput?

    private let wallet: MetaAccountModel
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol

    init(
        wallet: MetaAccountModel,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.wallet = wallet
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.chainRepository = chainRepository
        self.operationManager = operationManager
    }

    deinit {
        cloudStorage?.disconnect()
    }

    // MARK: - Private methods

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletBalance(
            wallet: wallet,
            deliverOn: nil,
            listener: self
        )
    }

    private func fetchChains() {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            switch fetchOperation.result {
            case let .success(chains):
                self?.output?.didReceive(chains: chains)
            case let .failure(error):
                self?.output?.didReceive(error: error)
            case .none:
                let error = BaseOperationError.parentOperationCancelled
                self?.output?.didReceive(error: error)
            }
        }

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    private func provideAvailableExportOptions() {
        let options = availableExportOptionsProvider.getAvailableExportOptions(
            for: wallet,
            accountId: nil
        )
        output?.didReceive(options: options)
    }

    private func getBackupAccounts() {
        Task {
            do {
                if let cloudStorage = cloudStorage {
                    let accounts = try await cloudStorage.getFearlessBackupAccounts()
                    await MainActor.run {
                        output?.didReceiveBackupAccounts(result: .success(accounts))
                    }
                }
            } catch {
                cloudStorage?.disconnect()
                await MainActor.run {
                    output?.didReceiveBackupAccounts(result: .failure(error))
                }
            }
        }
    }
}

// MARK: - BackupWalletInteractorInput

extension BackupWalletInteractor: BackupWalletInteractorInput {
    func viewDidAppear() {
        getBackupAccounts()
    }

    func removeBackupFromGoogle() {
        let address42 = try? wallet.substratePublicKey.toAddress(using: .substrate(42))
        let account = OpenBackupAccount(address: address42 ?? wallet.substratePublicKey.toHex())

        Task {
            do {
                try await cloudStorage?.deleteBackup(account: account)
                await MainActor.run {
                    output?.didReceiveRemove(result: .success(()))
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveRemove(result: .failure(error))
                }
            }
        }
    }

    func setup(with output: BackupWalletInteractorOutput) {
        self.output = output
        provideAvailableExportOptions()
        fetchBalances()
        fetchChains()
    }
}

// MARK: - WalletBalanceSubscriptionHandler

extension BackupWalletInteractor: WalletBalanceSubscriptionListener {
    var type: WalletBalanceListenerType {
        .wallet(wallet: wallet)
    }

    func handle(result: WalletBalancesResult) {
        output?.didReceiveBalances(result: result)
    }
}
