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
    var cloudStorage: CloudStorageServiceProtocol?

    // MARK: - Private properties

    private weak var output: BackupWalletInteractorOutput?

    private let wallet: MetaAccountModel
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let validateCloudConfiguration: () throws -> Void

    init(
        wallet: MetaAccountModel,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        validateCloudConfiguration: @escaping () throws -> Void = {
            _ = try GoogleDriveBackupOAuthConfiguration(info: Bundle.main.infoDictionary ?? [:])
        }
    ) {
        self.wallet = wallet
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.chainRepository = chainRepository
        self.operationManager = operationManager
        self.validateCloudConfiguration = validateCloudConfiguration
    }

    deinit {
        cloudStorage?.disconnect()
    }

    // MARK: - Private methods

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletBalance(
            wallet: wallet,
            listener: self
        )
    }

    private func fetchChains() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let chains = try await chainRepository.fetchAllAsync()
                await MainActor.run { [weak self] in
                    self?.output?.didReceive(chains: chains)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.output?.didReceive(error: error)
                }
            }
        }
    }

    private func provideAvailableExportOptions() {
        let options = availableExportOptionsProvider.getAvailableExportOptions(
            for: wallet,
            accountId: nil
        )
        output?.didReceive(options: options)
    }

    private func configuredCloudStorage() throws -> CloudStorageServiceProtocol {
        try validateCloudConfiguration()
        guard let cloudStorage else {
            throw GoogleDrivePasskeyBackupError.unavailableConfiguration
        }
        return cloudStorage
    }

    private func getBackupAccounts() {
        Task {
            do {
                let cloudStorage = try configuredCloudStorage()
                let accounts = try await cloudStorage.getBackupAccounts()
                await MainActor.run {
                    output?.didReceiveBackupAccounts(result: .success(accounts))
                }
            } catch {
                if error as? GoogleDrivePasskeyBackupError != .unavailableConfiguration {
                    cloudStorage?.disconnect()
                }
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
        let account = OpenBackupAccount(address: wallet.backupAddress)

        Task {
            do {
                let cloudStorage = try configuredCloudStorage()
                try await cloudStorage.deleteBackup(account: account)
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
