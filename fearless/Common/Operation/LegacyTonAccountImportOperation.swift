import Foundation
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import TonSwift

struct LegacyTonImportCandidate {
    enum Form { case asTyped, normalized }
    let form: Form
    let phrase: String
    let publicKey: Data
    let address: String

    var mnemonic: LegacyTonMnemonic {
        LegacyTonMnemonic(phrase: phrase, importPublicKey: publicKey)
    }
}

enum LegacyTonImportError: Error { case ambiguousPhrase }

extension LegacyTonMnemonic {
    static func importCandidates(_ phrase: String) throws -> [LegacyTonImportCandidate] {
        let words = phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // Keep native phrase validation; only derivation preserves historical typed whitespace.
        guard !words.isEmpty, words.count <= 24,
              TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: words) else {
            throw AccountCreateError.invalidMnemonicFormat
        }
        let normalized = words.joined(separator: " ")
        let forms: [(LegacyTonImportCandidate.Form, String)] = [(.asTyped, phrase), (.normalized, normalized)]
        var candidates: [LegacyTonImportCandidate] = []
        for (form, text) in forms {
            let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: text.components(separatedBy: " "))
            guard !candidates.contains(where: { $0.publicKey == pair.publicKey.data }) else { continue }
            let address = try WalletV4R2(publicKey: pair.publicKey.data).address()
            candidates.append(LegacyTonImportCandidate(
                form: form, phrase: text, publicKey: pair.publicKey.data,
                address: address.toString(bounceable: false)
            ))
        }
        return candidates
    }

    static func validatedForImport(_ phrase: String) throws -> LegacyTonMnemonic {
        let candidates = try importCandidates(phrase)
        guard candidates.count == 1, let candidate = candidates.first else {
            throw LegacyTonImportError.ambiguousPhrase
        }
        return candidate.mnemonic
    }

    static func selectedForImport(_ phrase: String, publicKey: Data) throws -> LegacyTonMnemonic {
        let candidates = try importCandidates(phrase)
        guard let candidate = candidates.first(where: { $0.phrase == phrase && $0.publicKey == publicKey }) else {
            throw TonSendServiceError.invalidAccount
        }
        return candidate.mnemonic
    }
}

/// Native TON recovery writes only fresh wallet tags. The import interactor
/// commits them after wallet persistence, or removes them when that save fails.
final class LegacyTonAccountImportOperation: BaseOperation<MetaAccountModel>, PersistenceBoundKeychainOperation {
    private let keystore: KeystoreProtocol
    private let phrase: String
    private let username: String
    private let isBackuped: Bool
    private let selectedPublicKey: Data?
    private let stateLock = NSLock()
    private let transaction: ImportKeychainTransaction
    private var committed = false

    init(keystore: KeystoreProtocol, phrase: String, username: String, isBackuped: Bool, selectedPublicKey: Data? = nil) {
        self.keystore = keystore
        transaction = ImportKeychainTransaction(keystore: keystore)
        self.phrase = phrase
        self.username = username
        self.isBackuped = isBackuped
        self.selectedPublicKey = selectedPublicKey
        super.init()
    }

    override func main() {
        super.main()
        guard !isCancelled, result == nil else { return }
        stateLock.lock()
        defer { stateLock.unlock() }
        do {
            let mnemonic = try selectedPublicKey.map { try LegacyTonMnemonic.selectedForImport(phrase, publicKey: $0) }
                ?? LegacyTonMnemonic.validatedForImport(phrase)
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
                try transaction.addKey(data, with: tag)
            }
            try transaction.publish(wallet, replacing: nil)
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
        transaction.commit()
    }

    func rollbackKeychainChanges() throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        try rollbackWhileLocked()
    }

    private func rollbackWhileLocked() throws {
        guard !committed else { return }
        try transaction.rollback()
    }
}
