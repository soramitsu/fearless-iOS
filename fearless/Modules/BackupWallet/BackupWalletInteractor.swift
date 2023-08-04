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
    func didReceive(request: BackupCreatePasswordFlow.RequestType)
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
    private let keystore: KeystoreProtocol
    private let exportJsonWrapper: KeystoreExportWrapperProtocol

    init(
        wallet: MetaAccountModel,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol,
        exportJsonWrapper: KeystoreExportWrapperProtocol
    ) {
        self.wallet = wallet
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.chainRepository = chainRepository
        self.operationManager = operationManager
        self.keystore = keystore
        self.exportJsonWrapper = exportJsonWrapper
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
                    cloudStorage.disconnect()
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

    private func createMnemonicRequest(substrate: ChainAccountInfo, ethereum: ChainAccountInfo) {
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
            output?.didReceive(request: .mnemonic(request))
        } catch {
            output?.didReceive(error: error)
        }
    }

    private func createKeystoreRequest(accounts: [ChainAccountInfo]) {
        var jsons: [RestoreJson] = []

        for chainAccount in accounts {
            if let data = try? exportJsonWrapper.export(
                chainAccount: chainAccount.account,
                password: "",
                address: AddressFactory.address(for: chainAccount.account.accountId, chain: chainAccount.chain),
                metaId: wallet.metaId,
                accountId: chainAccount.account.isChainAccount ? chainAccount.account.accountId : nil,
                genesisHash: nil
            ), let result = String(data: data, encoding: .utf8) {
                do {
                    let fileUrl = try URL(fileURLWithPath: NSTemporaryDirectory() + "/\(AddressFactory.address(for: chainAccount.account.accountId, chain: chainAccount.chain)).json")
                    try result.write(toFile: fileUrl.path, atomically: true, encoding: .utf8)
                    let json = RestoreJson(
                        data: result,
                        chain: chainAccount.chain,
                        cryptoType: nil,
                        fileURL: fileUrl
                    )

                    jsons.append(json)
                } catch {
                    output?.didReceive(error: error)
                }
            }
        }
        output?.didReceive(request: .jsons(jsons))
    }

    private func createSeedRequest(accounts: [ChainAccountInfo]) {
        var seeds: [ExportSeedData] = []

        for chainAccount in accounts {
            let chain = chainAccount.chain
            let account = chainAccount.account
            let accountId = account.isChainAccount ? account.accountId : nil

            do {
                let seedTag = chain.isEthereumBased
                    ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
                    : KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: accountId)

                var optionalSeed: Data? = try keystore.fetchKey(for: seedTag)

                let keyTag = chain.isEthereumBased
                    ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
                    : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

                if optionalSeed == nil, account.cryptoType.supportsSeedFromSecretKey {
                    optionalSeed = try keystore.fetchKey(for: keyTag)
                }

                guard let seed = optionalSeed else {
                    throw ExportSeedInteractorError.missingSeed
                }

                //  We shouldn't show derivation path for ethereum seed. So just provide nil to hide it
                let derivationPathTag = chain.isEthereumBased
                    ? nil : KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)

                var derivationPath: String?
                if let tag = derivationPathTag {
                    derivationPath = try keystore.fetchDeriviationForAddress(tag)
                }

                let seedData = ExportSeedData(
                    seed: seed,
                    derivationPath: derivationPath,
                    chain: chain,
                    cryptoType: account.cryptoType
                )

                seeds.append(seedData)
            } catch {
                output?.didReceive(error: error)
            }
        }
        output?.didReceive(request: .seeds(seeds))
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
        cloudStorage?.deleteBackupAccount(account: account, completion: { [weak self] result in
            self?.output?.didReceiveRemove(result: result)
        })
    }

    func backup(substrate: ChainAccountInfo, ethereum: ChainAccountInfo?, option: ExportOption) {
        switch option {
        case .mnemonic:
            guard let ethereum = ethereum else {
                return
            }
            createMnemonicRequest(substrate: substrate, ethereum: ethereum)
        case .seed:
            createSeedRequest(accounts: [substrate, ethereum].compactMap { $0 })
        case .keystore:
            createKeystoreRequest(accounts: [substrate, ethereum].compactMap { $0 })
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
