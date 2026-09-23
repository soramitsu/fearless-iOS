import UIKit
import SSFCloudStorage
import RobinHood
import SoraKeystore
import IrohaCrypto
import SSFModels

protocol BackupCreatePasswordInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didComplete()
}

enum BackupCreatePasswordError: Error {
    case incompleteBackupMaterial
    case unavailableCloudStorage
    case cloudBackupReadbackMismatch
}

final class BackupCreatePasswordInteractor: BaseAccountConfirmInteractor {
    var cloudStorage: CloudStorageServiceProtocol?

    // MARK: - Private properties

    private weak var output: BackupCreatePasswordInteractorOutput?
    private let secretManager: SecretStoreManagerProtocol
    private let keystore: KeystoreProtocol
    private let exportJsonWrapper: KeystoreExportWrapperProtocol

    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol
    private var currentOperation: Operation?
    private let createPasswordFlow: BackupCreatePasswordFlow

    private var password: String?

    init(
        createPasswordFlow: BackupCreatePasswordFlow,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        settings: SelectedWalletSettings,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        secretManager: SecretStoreManagerProtocol,
        keystore: KeystoreProtocol,
        exportJsonWrapper: KeystoreExportWrapperProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.createPasswordFlow = createPasswordFlow
        self.secretManager = secretManager
        self.keystore = keystore
        self.exportJsonWrapper = exportJsonWrapper

        var flow: AccountConfirmFlow?
        if let mnemonicRequest = createPasswordFlow.mnemonicRequest {
            flow = .wallet(mnemonicRequest)
        }

        super.init(
            flow: flow,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: operationManager
        )
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        guard currentOperation == nil else {
            return
        }

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation {
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return accountItem
        }

        saveOperation.completionBlock = { [weak self] in
            self?.currentOperation = nil
            self?.handleCreateAccountOperation(result: saveOperation.result)
        }

        saveOperation.addDependency(importOperation)

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }

    // MARK: - Private methods

    // create new wallet with google backup flow
    private func handleCreateAccountOperation(result: Result<MetaAccountModel, Error>?) {
        switch result {
        case let .success(wallet):
            settings.save(value: wallet, runningCompletionIn: .main) { result in
                switch result {
                case let .success(savedWallet):
                    self.eventCenter.notify(with: SelectedAccountChanged(account: savedWallet))
                    switch self.flow {
                    case let .wallet(request):
                        self.saveBackupAccount(wallet: savedWallet, requestType: .mnemonic(request))
                    default:
                        break
                    }
                case let .failure(error):
                    self.output?.didReceive(error: error)
                }
            }

        case let .failure(error):
            output?.didReceive(error: error)

        case .none:
            let error = BaseOperationError.parentOperationCancelled
            output?.didReceive(error: error)
        }
    }

    private func saveBackupAccount(wallet: MetaAccountModel, requestType: BackupCreatePasswordFlow.RequestType) {
        guard let password = password else {
            output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
            return
        }

        switch requestType {
        case let .mnemonic(metaAccountImportMnemonicRequest):
            backupMnemonic(wallet: wallet, request: metaAccountImportMnemonicRequest, password: password)
        case let .jsons(jsons):
            backupJsons(wallet: wallet, jsons: jsons, password: password)
        case let .seeds(seeds):
            backupSeeds(wallet: wallet, seeds: seeds, password: password)
        }
    }

    private func backupSeeds(
        wallet: MetaAccountModel,
        seeds: [ExportSeedData],
        password: String
    ) {
        guard !seeds.isEmpty else {
            output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
            return
        }
        let substrateRestoreSeed = seeds.first(where: { !$0.chain.isEthereumBased })
        let ethereumRestoreSeed = seeds.first(where: { $0.chain.isEthereumBased })

        let substrateSeed = substrateRestoreSeed?.seed.toHex(includePrefix: true)
        let ethSeed = ethereumRestoreSeed?.seed.toHex(includePrefix: true)
        let seed = OpenBackupAccount.Seed(
            substrateSeed: substrateSeed,
            ethSeed: ethSeed
        )
        let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType)
        let address42 = wallet.backupAddress

        let account = OpenBackupAccount(
            name: wallet.name,
            address: wallet.backupAddress,
            cryptoType: cryptoType?.stringValue.uppercased(),
            substrateDerivationPath: substrateRestoreSeed?.derivationPath,
            ethDerivationPath: ethereumRestoreSeed?.derivationPath,
            backupAccountType: [.seed],
            encryptedSeed: seed
        )
        saveBackupAccountToCloudStorage(account: account, password: password, wallet: wallet)
    }

    private func backupJsons(
        wallet: MetaAccountModel,
        jsons: [RestoreJson],
        password: String
    ) {
        guard !jsons.isEmpty else {
            output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
            return
        }
        let substrateRestoreJson = jsons.first(where: { !$0.chain.isEthereumBased })
        let ethereumRestoreJson = jsons.first(where: { $0.chain.isEthereumBased })

        let json = OpenBackupAccount.Json(
            substrateJson: substrateRestoreJson?.data,
            ethJson: ethereumRestoreJson?.data
        )
        let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType)
        let address42 = wallet.backupAddress

        let account = OpenBackupAccount(
            name: wallet.name,
            address: wallet.backupAddress,
            cryptoType: cryptoType?.stringValue.uppercased(),
            backupAccountType: [.json],
            json: json
        )
        saveBackupAccountToCloudStorage(account: account, password: password, wallet: wallet)
    }

    private func backupMnemonic(
        wallet: MetaAccountModel,
        request: MetaAccountImportMnemonicRequest,
        password: String
    ) {
        let address42 = wallet.backupAddress
        let account = OpenBackupAccount(
            name: request.username,
            address: wallet.backupAddress,
            passphrase: request.mnemonic.toString(),
            cryptoType: request.cryptoType.stringValue.uppercased(),
            substrateDerivationPath: request.substrateDerivationPath,
            ethDerivationPath: request.ethereumDerivationPath,
            backupAccountType: [.passphrase]
        )
        saveBackupAccountToCloudStorage(account: account, password: password, wallet: wallet)
    }

    private func saveBackupAccountToCloudStorage(
        account: OpenBackupAccount,
        password: String,
        wallet: MetaAccountModel
    ) {
        guard let cloudStorage = cloudStorage else {
            output?.didReceive(error: BackupCreatePasswordError.unavailableCloudStorage)
            return
        }
        Task {
            do {
                try await cloudStorage.saveBackup(account: account, password: password)
                let downloaded = try await cloudStorage.importBackup(account: account, password: password)
                guard Self.matchesReadback(downloaded, expected: account) else {
                    throw BackupCreatePasswordError.cloudBackupReadbackMismatch
                }
                didBackuped(wallet: wallet) { result in
                    DispatchQueue.main.async { [weak self] in
                        switch result {
                        case .success:
                            self?.output?.didComplete()
                        case let .failure(error):
                            self?.output?.didReceive(error: error)
                        }
                    }
                }
            } catch {
                await MainActor.run { self.output?.didReceive(error: error) }
            }
        }
    }

    private static func matchesReadback(_ actual: OpenBackupAccount, expected: OpenBackupAccount) -> Bool {
        actual.address == expected.address &&
            actual.name == expected.name &&
            actual.cryptoType == expected.cryptoType &&
            actual.substrateDerivationPath == expected.substrateDerivationPath &&
            actual.ethDerivationPath == expected.ethDerivationPath &&
            actual.backupAccountType == expected.backupAccountType &&
            actual.passphrase == expected.passphrase &&
            actual.json?.substrateJson == expected.json?.substrateJson &&
            actual.json?.ethJson == expected.json?.ethJson &&
            actual.encryptedSeed?.substrateSeed == expected.encryptedSeed?.substrateSeed &&
            actual.encryptedSeed?.ethSeed == expected.encryptedSeed?.ethSeed
    }

    private func didBackuped(wallet: MetaAccountModel, completion: @escaping (Result<Void, Error>) -> Void) {
        let updatedWallet = wallet.replacingIsBackuped(true)
        let saveOperation = accountRepository.saveOperation {
            [updatedWallet]
        } _: {
            []
        }
        saveOperation.completionBlock = { [weak saveOperation] in
            do {
                guard let saveOperation = saveOperation else {
                    throw BaseOperationError.parentOperationCancelled
                }
                _ = try saveOperation.extractNoCancellableResultData()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    private func saveMnemonic(
        wallet: MetaAccountModel,
        substrate: ChainAccountInfo,
        ethereum: ChainAccountInfo
    ) {
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
                cryptoType: substrate.account.cryptoType,
                defaultChainId: nil
            )
            saveBackupAccount(wallet: wallet, requestType: .mnemonic(request))
        } catch {
            output?.didReceive(error: error)
        }
    }

    private func saveKeystore(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        password: String
    ) {
        var jsons: [RestoreJson] = []

        for chainAccount in accounts {
            do {
                let address = try AddressFactory.address(
                    for: chainAccount.account.accountId, chain: chainAccount.chain
                )
                let data = try exportJsonWrapper.export(
                    chainAccount: chainAccount.account,
                    password: password,
                    address: address,
                    metaId: wallet.metaId,
                    accountId: chainAccount.account.isChainAccount ? chainAccount.account.accountId : nil,
                    genesisHash: nil
                )
                guard let result = String(data: data, encoding: .utf8) else {
                    throw BackupCreatePasswordError.incompleteBackupMaterial
                }
                let fileURL = URL(fileURLWithPath: NSTemporaryDirectory() + "/\(address).json")
                try result.write(to: fileURL, atomically: true, encoding: .utf8)
                jsons.append(RestoreJson(
                    data: result, chain: chainAccount.chain, cryptoType: nil, fileURL: fileURL
                ))
            } catch {
                output?.didReceive(error: error)
                return
            }
        }
        guard jsons.count == accounts.count, !jsons.isEmpty else {
            output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
            return
        }
        saveBackupAccount(wallet: wallet, requestType: .jsons(jsons))
    }

    private func saveSeed(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo]
    ) {
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
                return
            }
        }
        guard seeds.count == accounts.count, !seeds.isEmpty else {
            output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
            return
        }
        saveBackupAccount(wallet: wallet, requestType: .seeds(seeds))
    }
}

// MARK: - BackupCreatePasswordInteractorInput

extension BackupCreatePasswordInteractor: BackupCreatePasswordInteractorInput {
    func setup(with output: BackupCreatePasswordInteractorOutput) {
        self.output = output
    }

    func createAndBackupAccount(password: String) {
        self.password = password

        switch createPasswordFlow {
        case .createWallet:
            skipConfirmation()
        case let .backupWallet(flow, options):
            switch flow {
            case let .multiple(wallet, selectedAccounts):
                let ethereum = selectedAccounts.first(where: { $0.chain.isEthereumBased })
                guard let substrate = selectedAccounts.first(where: { !$0.chain.isEthereumBased }) else {
                    output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
                    return
                }
                let accounts = [substrate, ethereum].compactMap { $0 }
                guard accounts.count == selectedAccounts.count else {
                    output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
                    return
                }

                if options.contains(.mnemonic) {
                    guard let ethereum = ethereum else {
                        output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
                        return
                    }
                    saveMnemonic(
                        wallet: wallet,
                        substrate: substrate,
                        ethereum: ethereum
                    )
                } else if options.contains(.seed) {
                    saveSeed(wallet: wallet, accounts: accounts)
                } else if options.contains(.keystore) {
                    saveKeystore(wallet: wallet, accounts: accounts, password: password)
                } else {
                    output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
                }
            case .single:
                // not support chain account backup
                output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
            }
        }
    }

    func hasPincode() -> Bool {
        secretManager.checkSecret(for: KeystoreTag.pincode.rawValue)
    }
}
