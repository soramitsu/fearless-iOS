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
    func didReceive(mnemonicRequest: MetaAccountImportMnemonicRequest)
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
    private let keystore: KeystoreProtocol

    init(
        wallet: MetaAccountModel,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol
    ) {
        self.wallet = wallet
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.chainRepository = chainRepository
        self.operationManager = operationManager
        self.keystore = keystore
    }

    // MARK: - Private methods

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletBalance(
            walletId: wallet.identifier,
            deliverOn: nil,
            handler: self
        )
    }

    private func fetchChains() {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            switch fetchOperation.result {
            case let .success(chains):
                self?.output?.didReceive(chains: chains)
            default:
                break
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
        cloudStorage?.getBackupAccounts(completion: { [weak self] result in
            self?.output?.didReceiveBackupAccounts(result: result)
        })
    }
}

// MARK: - BackupWalletInteractorInput

extension BackupWalletInteractor: BackupWalletInteractorInput {
    func viewDidAppear() {
        getBackupAccounts()
    }

    func removeBackupFromGoogle() {
        let account = OpenBackupAccount(address: wallet.substrateAccountId.toHex())
        cloudStorage?.deleteBackupAccount(account: account, completion: { [weak self] result in
            self?.output?.didReceiveRemove(result: result)
        })
    }

    func backup(substrate: ChainAccountInfo, ethereum: ChainAccountInfo) {
        do {
            let substrateAccountId = substrate.account.isChainAccount ? substrate.account.accountId : nil
            let ethereumAccountId = ethereum.account.isChainAccount ? ethereum.account.accountId : nil
            let entropyTag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: substrateAccountId)
            let entropy = try keystore.fetchKey(for: entropyTag)

            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)

            let substrateDerivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: substrateAccountId)
            let ethereumDerivationTag = KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: ethereumAccountId)

            let substrateDerivationPath: String = try keystore.fetchDeriviationForAddress(substrateDerivationTag) ?? ""
            guard let ethereumDerivationPath: String = try keystore.fetchDeriviationForAddress(ethereumDerivationTag) else {
                throw ConvenienceError(error: "Can't fetch derivation path for ethereum account")
            }

            let request = MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic,
                username: wallet.name,
                substrateDerivationPath: substrateDerivationPath,
                ethereumDerivationPath: ethereumDerivationPath,
                cryptoType: substrate.account.cryptoType
            )
            output?.didReceive(mnemonicRequest: request)
        } catch {
            output?.didReceive(error: error)
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

extension BackupWalletInteractor: WalletBalanceSubscriptionHandler {
    func handle(result: WalletBalancesResult) {
        output?.didReceiveBalances(result: result)
    }
}
