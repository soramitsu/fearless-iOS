import Foundation
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import TonSwift

extension LegacyTonMnemonic {
    static func validatedForImport(_ phrase: String) throws -> LegacyTonMnemonic {
        let words = phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // Released import accepted valid native phrases up to 24 words.
        guard !words.isEmpty, words.count <= 24,
              TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: words) else {
            throw AccountCreateError.invalidMnemonicFormat
        }
        return LegacyTonMnemonic(phrase: words.joined(separator: " "))
    }
}

/// Native TON recovery writes only fresh wallet tags. The import interactor
/// commits them after wallet persistence, or removes them when that save fails.
final class LegacyTonAccountImportOperation: BaseOperation<MetaAccountModel>, PersistenceBoundKeychainOperation {
    private let keystore: KeystoreProtocol
    private let phrase: String
    private let username: String
    private let isBackuped: Bool
    private let stateLock = NSLock()
    private var stagedTags: [String] = []
    private var committed = false

    init(keystore: KeystoreProtocol, phrase: String, username: String, isBackuped: Bool) {
        self.keystore = keystore
        self.phrase = phrase
        self.username = username
        self.isBackuped = isBackuped
        super.init()
    }

    override func main() {
        super.main()
        guard !isCancelled, result == nil else { return }
        stateLock.lock()
        defer { stateLock.unlock() }
        do {
            let mnemonic = try LegacyTonMnemonic.validatedForImport(phrase)
            let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.allWords())
            let address = try WalletV4R2(publicKey: pair.publicKey.data).address()
            let legacy = try LegacyTonAccount(
                serializedAddress: JSONEncoder().encode(address),
                publicKey: pair.publicKey.data,
                contractVersion: "v4R2"
            )
            let privateKey = try legacy.validatedPrivateKey(pair.privateKey.data)
            let metaId = UUID().uuidString
            let wallet = MetaAccountModel(
                metaId: metaId, name: username,
                substrateAccountId: nil, substrateCryptoType: CryptoType.ed25519.rawValue,
                substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil,
                chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: false,
                unusedChainIds: nil, selectedCurrency: Currency.defaultCurrency(),
                networkManagmentFilter: nil, assetsVisibility: [], hasBackup: isBackuped,
                favouriteChainIds: [], legacyTonAccount: legacy
            )
            let writes = [
                (KeystoreTagV2.tonSecretKeyTagForMetaId(metaId), privateKey),
                (KeystoreTagV2.entropyTagForMetaId(metaId), mnemonic.entropy())
            ]
            // Even an unexpected UUID collision must not replace any old secret.
            for (tag, _) in writes {
                guard try !keystore.checkKey(for: tag) else { throw TonSendServiceError.invalidAccount }
            }
            for (tag, data) in writes {
                stagedTags.append(tag)
                try keystore.saveKey(data, with: tag)
            }
            result = .success(wallet)
        } catch {
            do {
                try rollbackWhileLocked()
                result = .failure(error)
            } catch let rollbackError {
                result = .failure(rollbackError)
            }
        }
    }

    func commitKeychainChanges() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard case .success? = result else { return }
        committed = true
        stagedTags.removeAll()
    }

    func rollbackKeychainChanges() throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        try rollbackWhileLocked()
    }

    private func rollbackWhileLocked() throws {
        guard !committed else { return }
        var firstError: Error?
        for tag in stagedTags.reversed() {
            do {
                try keystore.deleteKeyIfExists(for: tag)
                stagedTags.removeAll { $0 == tag }
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }

    deinit {
        try? rollbackKeychainChanges()
    }
}
