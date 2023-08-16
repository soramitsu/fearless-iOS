import UIKit
import SSFCloudStorage
import RobinHood
import SoraKeystore
import IrohaCrypto

protocol BackupCreatePasswordInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didComplete()
}

final class BackupCreatePasswordInteractor: BaseAccountConfirmInteractor {
    var cloudStorage: FearlessCompatibilityProtocol?

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

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            self?.settings.save(value: accountItem)

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
            settings.setup()
            eventCenter.notify(with: SelectedAccountChanged())
            switch flow {
            case let .wallet(request):
                saveBackupAccount(wallet: wallet, requestType: .mnemonic(request))
            default:
                break
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
        let substrateRestoreSeed = seeds.first(where: { $0.chain.chainBaseType == .substrate })
        let ethereumRestoreSeed = seeds.first(where: { $0.chain.isEthereumBased })

        let substrateSeed = substrateRestoreSeed?.seed.toHex(includePrefix: true)
        let ethSeed = ethereumRestoreSeed?.seed.toHex(includePrefix: true)
        let seed = OpenBackupAccount.Seed(
            substrateSeed: substrateSeed,
            ethSeed: ethSeed
        )
        let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType)
        let address42 = try? wallet.substratePublicKey.toAddress(using: .substrate(42))

        let account = OpenBackupAccount(
            name: wallet.name,
            address: address42 ?? wallet.substratePublicKey.toHex(),
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
        let substrateRestoreJson = jsons.first(where: { $0.chain.chainBaseType == .substrate })
        let ethereumRestoreJson = jsons.first(where: { $0.chain.isEthereumBased })

        let json = OpenBackupAccount.Json(
            substrateJson: substrateRestoreJson?.data,
            ethJson: ethereumRestoreJson?.data
        )
        let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType)
        let address42 = try? wallet.substratePublicKey.toAddress(using: .substrate(42))

        let account = OpenBackupAccount(
            name: wallet.name,
            address: address42 ?? wallet.substratePublicKey.toHex(),
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
        let address42 = try? wallet.substratePublicKey.toAddress(using: .substrate(42))
        let account = OpenBackupAccount(
            name: request.username,
            address: address42 ?? wallet.substratePublicKey.toHex(),
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
        cloudStorage?.saveBackupAccount(
            account: account,
            password: password
        ) { [weak self] result in
            switch result {
            case .success:
                self?.didBackuped(wallet: wallet)
                DispatchQueue.main.async {
                    self?.output?.didComplete()
                }
            case let .failure(failure):
                self?.output?.didReceive(error: failure)
            }
        }
    }

    private func didBackuped(wallet: MetaAccountModel) {
        let updatedWallet = wallet.replacingIsBackuped(true)
        let saveOperation = accountRepository.saveOperation {
            [updatedWallet]
        } _: {
            []
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
                cryptoType: substrate.account.cryptoType
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
            if let data = try? exportJsonWrapper.export(
                chainAccount: chainAccount.account,
                password: password,
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
            }
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
            case let .multiple(wallet, accounts):
                let ethereum = accounts.first(where: { $0.chain.isEthereumBased })
                guard let substrate = accounts.first(where: { $0.chain.chainBaseType == .substrate }) else {
                    return
                }
                let accounts = [substrate, ethereum].compactMap { $0 }

                if options.contains(.mnemonic) {
                    guard let ethereum = ethereum else {
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
                }
            case .single:
                // not support chain account backup
                break
            }
        }
    }

    func hasPincode() -> Bool {
        secretManager.checkSecret(for: KeystoreTag.pincode.rawValue)
    }
}
