import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFModels
import UIKit

protocol BackupCreatePasswordInteractorOutput: AnyObject {
    func didReceive(error: Error)
    /// The backup is on Google Drive and read back intact. `accountsNotRestored` are the
    /// wallet's Bitcoin, Solana and Taira accounts that restoring it would not give back.
    func didComplete(accountsNotRestored: [ChainAccountModel])
}

enum BackupCreatePasswordError: Error {
    case incompleteBackupMaterial
    case unavailableCloudStorage
    case cloudBackupReadbackMismatch
    /// The backup format has no slot for a TON phrase.
    case nativeTonWalletNotSupported
    /// Every restore of the backup format needs the wallet's Substrate key.
    case walletWithoutSubstrateAccount
    /// The stored phrase does not recreate the wallet's own accounts.
    case unverifiedRecoveryPhrase
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
    private let logger: LoggerProtocol
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
        exportJsonWrapper: KeystoreExportWrapperProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.createPasswordFlow = createPasswordFlow
        self.secretManager = secretManager
        self.keystore = keystore
        self.exportJsonWrapper = exportJsonWrapper
        self.logger = logger

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
            try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        saveOperation.completionBlock = { [weak self] in
            let result = saveOperation.result
            saveOperation.completionBlock = nil
            DispatchQueue.main.async {
                guard let self else {
                    ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                    return
                }
                self.handleCreateAccountOperation(result: result, importOperation: importOperation)
            }
        }

        saveOperation.addDependency(importOperation)
        currentOperation = saveOperation
        operationManager.enqueue(operations: [importOperation, saveOperation], in: .transient)
    }

    /// The local wallet acknowledgement owns the keys. A later cloud failure cannot undo it.
    private func handleCreateAccountOperation(
        result: Result<MetaAccountModel, Error>?, importOperation: BaseOperation<MetaAccountModel>
    ) {
        switch result {
        case let .success(wallet):
            settings.save(value: wallet, runningCompletionIn: .main) { [weak self] result in
                self?.currentOperation = nil
                switch result {
                case let .success(savedWallet):
                    (importOperation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
                    guard let self else { return }
                    self.eventCenter.notify(with: SelectedAccountChanged(account: savedWallet))
                    if case let .wallet(request) = self.flow {
                        self.saveBackupAccount(wallet: savedWallet, requestType: .mnemonic(request))
                    }
                case let .failure(error):
                    let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
                    self?.output?.didReceive(error: failure)
                }
            }
        case let .failure(error):
            currentOperation = nil
            let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
            output?.didReceive(error: failure)
        case .none:
            currentOperation = nil
            let failure = ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
            output?.didReceive(error: failure)
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

        // The Ethereum seed is the private key itself and needs no path, but iOS releases before
        // 4.2 import it only when the backup also carries one. An empty path keeps the key as it
        // is; Android ignores the path for a seed.
        let account = OpenBackupAccount(
            name: wallet.name,
            address: wallet.backupAddress,
            cryptoType: cryptoType?.stringValue.uppercased(),
            substrateDerivationPath: substrateRestoreSeed?.derivationPath,
            ethDerivationPath: ethereumRestoreSeed.map { $0.derivationPath ?? "" },
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
                let downloaded = try await cloudStorage.saveBackupAndImport(
                    account: account, password: password
                )
                guard Self.matchesReadback(downloaded, expected: account) else {
                    throw BackupCreatePasswordError.cloudBackupReadbackMismatch
                }
                let accountsNotRestored = GoogleDriveBackupContent.appOwnedAccountsNotRestored(
                    from: wallet,
                    by: downloaded
                )
                didBackuped(wallet: wallet) { result in
                    DispatchQueue.main.async { [weak self] in
                        switch result {
                        case .success:
                            self?.output?.didComplete(accountsNotRestored: accountsNotRestored)
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

    /// Uploads the most complete backup the wallet's stored keys prove: its recovery phrase,
    /// otherwise its raw seeds, otherwise JSON files of its keys. A phrase or a seed is used
    /// only if it recreates the wallet's own accounts, so a wallet is never marked as backed up
    /// by a file that restores another address.
    private func backupWallet(
        _ wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        options: [ExportOption],
        password: String
    ) {
        let requestType: BackupCreatePasswordFlow.RequestType
        do {
            let content = try GoogleDriveBackupContent(wallet: wallet, accounts: accounts)
            requestType = try backupMaterial(
                wallet: wallet,
                content: content,
                options: options,
                password: password
            )
        } catch let error as BackupCreatePasswordError {
            output?.didReceive(error: error)
            return
        } catch {
            logger.error("Google Drive backup has no usable key material: \(error)")
            output?.didReceive(error: BackupCreatePasswordError.incompleteBackupMaterial)
            return
        }

        saveBackupAccount(wallet: wallet, requestType: requestType)
    }
}

// MARK: - Google Drive backup material

private extension BackupCreatePasswordInteractor {
    func backupMaterial(
        wallet: MetaAccountModel,
        content: GoogleDriveBackupContent,
        options: [ExportOption],
        password: String
    ) throws -> BackupCreatePasswordFlow.RequestType {
        if options.contains(.mnemonic), let ethereum = content.ethereum {
            do {
                let request = try verifiedMnemonicRequest(
                    wallet: wallet,
                    substrate: content.substrate,
                    ethereum: ethereum
                )
                return .mnemonic(request)
            } catch {
                logger.warning("Google Drive backup does not use the recovery phrase: \(error)")
            }
        }

        if options.contains(.seed) {
            do {
                return try .seeds(verifiedSeeds(wallet: wallet, accounts: content.accounts))
            } catch {
                logger.warning("Google Drive backup does not use the raw seeds: \(error)")
            }
        }

        guard options.contains(.keystore) else {
            throw BackupCreatePasswordError.incompleteBackupMaterial
        }

        return try .jsons(keystoreJsons(wallet: wallet, accounts: content.accounts, password: password))
    }

    func verifiedMnemonicRequest(
        wallet: MetaAccountModel,
        substrate: ChainAccountInfo,
        ethereum: ChainAccountInfo
    ) throws -> MetaAccountImportMnemonicRequest {
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

        // The phrase is the wallet's backup only if importing it recreates both of its accounts.
        let derivation = MetaAccountOperationFactory(keystore: keystore)
        // A wallet imported with an earlier browser extension's account restores it: the restore
        // picks the rule whose account the backup is filed under (SubstratePasswordRule).
        let substrateRestores = try derivation.entropyReproducesPublicKey(
            entropy,
            derivationPath: substrateDerivationPath,
            cryptoType: substrate.account.cryptoType,
            publicKey: substrate.account.publicKey
        )
        let ethereumAddress = try derivation.publicKeyForExportEntropy(
            entropy,
            derivationPath: ethereumDerivationPath,
            cryptoType: .ecdsa,
            ethereumBased: true
        ).ethereumAddressFromPublicKey()

        guard
            substrateRestores,
            ethereumAddress == ethereum.account.accountId
        else {
            throw BackupCreatePasswordError.unverifiedRecoveryPhrase
        }

        return MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: wallet.name,
            substrateDerivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethereumDerivationPath,
            cryptoType: substrate.account.cryptoType,
            defaultChainId: nil
        )
    }

    func keystoreJsons(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        password: String
    ) throws -> [RestoreJson] {
        let jsons = try accounts.map { chainAccount -> RestoreJson in
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
            return RestoreJson(data: result, chain: chainAccount.chain, cryptoType: nil, fileURL: fileURL)
        }
        guard !jsons.isEmpty else {
            throw BackupCreatePasswordError.incompleteBackupMaterial
        }
        return jsons
    }

    func verifiedSeeds(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo]
    ) throws -> [ExportSeedData] {
        // A seed that does not recreate its account must never be uploaded as its backup.
        let seedReader = VerifiedSeedExportReader(keystore: keystore)

        let seeds = try accounts.map { chainAccount -> ExportSeedData in
            let chain = chainAccount.chain
            let account = chainAccount.account
            let accountId = account.isChainAccount ? account.accountId : nil

            let export = try seedReader.fetchSeed(
                metaId: wallet.metaId,
                accountId: accountId,
                publicKey: account.publicKey,
                cryptoType: account.cryptoType,
                ethereumBased: chain.isEthereumBased
            )

            return ExportSeedData(
                seed: export.seed,
                derivationPath: export.derivationPath,
                chain: chain,
                cryptoType: account.cryptoType
            )
        }
        guard !seeds.isEmpty else {
            throw BackupCreatePasswordError.incompleteBackupMaterial
        }
        return seeds
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
            case let .multiple(wallet, accounts):
                // Verifying the phrase and encrypting JSON files takes a moment; keep it off the main thread.
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.backupWallet(wallet, accounts: accounts, options: options, password: password)
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
