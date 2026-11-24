import Foundation
import IrohaCrypto
import SoraKeystore
import SSFModels
import TonSwift

/// Lets the owner of a wallet an earlier release made show they still have its recovery phrase,
/// so the wallet may move to protected storage (design doc 3.5, precondition 4). Offered once per
/// wallet and only while the flag is on; skipping leaves the wallet exactly as it is.
///
/// The typed phrase must re-derive every public key the wallet stores, with the standard
/// derivation paths (a custom path or wallet password would be needed to restore and is not
/// asked for here). Only then is recovery evidence recorded for the wallet's items. The stored
/// phrase is never shown; the stored paths are read to check they are the standard ones.
final class ProtectedKeychainRecoveryCheck {
    enum Outcome: Equatable {
        /// Every stored public key matched: evidence recorded for every item.
        case verified
        /// The words do not re-derive this wallet.
        case mismatch
        /// The wallet uses a custom derivation path or password: it stays as it is.
        case customPath
        /// Nothing here can be checked (the keychain could not be read): it stays as it is.
        case unavailable
    }

    static let shared = ProtectedKeychainRecoveryCheck()
    static let offeredKey = "protectedKeychain.recoveryCheckOffered.v1"

    private let inventory: LegacyKeychainInventory
    private let keystore: KeystoreProtocol
    private let evidence: ProtectedKeychainRecoveryEvidence
    private let userDefaults: UserDefaults
    private let isEnabled: () -> Bool
    private let lock = NSLock()

    init(
        inventory: LegacyKeychainInventory = Keychain(routed: false),
        keystore: KeystoreProtocol = Keychain(),
        evidence: ProtectedKeychainRecoveryEvidence = .shared,
        userDefaults: UserDefaults = .standard,
        isEnabled: @escaping () -> Bool = { ProtectedKeychainPolicy.isEnabled }
    ) {
        self.inventory = inventory
        self.keystore = keystore
        self.evidence = evidence
        self.userDefaults = userDefaults
        self.isEnabled = isEnabled
    }

    // MARK: Offer

    /// Public data only (the attribute inventory; no secret is read): the flag is on, the wallet
    /// was never offered the check, some of its items lack evidence, and they are all root items of
    /// a phrase wallet (a BIP39 phrase or a released native TON phrase). Accounts imported on their
    /// own, raw-seed and JSON-only wallets cannot be covered by one phrase and are never offered.
    func shouldOffer(_ wallet: MetaAccountModel) -> Bool {
        guard isEnabled(), !wasOffered(wallet.metaId), let tags = walletTags(wallet) else {
            return false
        }
        guard !tags.allSatisfy({ evidence.covers(tag: $0, walletId: wallet.metaId) }) else {
            return false
        }
        let root = { (suffix: String) in wallet.metaId + suffix }
        guard tags.allSatisfy({ WalletSecretTag.accountScope(of: $0, walletId: wallet.metaId) == "" }),
              tags.contains(root("-entropy")),
              !tags.contains(root("-universalWalletSecretSource"))
        else {
            return false
        }
        if wallet.legacyTonAccount != nil {
            return Set(tags).isSubset(of: [root("-entropy"), root("-tonSecretKey")])
        }
        return wallet.substratePublicKey != nil || wallet.ethereumPublicKey != nil
    }

    /// Closing the offer in any way counts: it is never shown for this wallet again.
    func markOffered(_ walletId: MetaAccountId) {
        lock.lock()
        defer { lock.unlock() }
        var offered = Set(userDefaults.stringArray(forKey: Self.offeredKey) ?? [])
        offered.insert(walletId)
        userDefaults.set(offered.sorted(), forKey: Self.offeredKey)
    }

    func wasOffered(_ walletId: MetaAccountId) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return (userDefaults.stringArray(forKey: Self.offeredKey) ?? []).contains(walletId)
    }

    // MARK: Check

    /// Checks `phrase` against `wallet`. Slow (key derivation): call it off the main thread.
    func verify(phrase: String, wallet: MetaAccountModel) -> Outcome {
        guard let tags = walletTags(wallet), !tags.isEmpty else {
            return .unavailable
        }
        let words = phrase
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else {
            return .mismatch
        }

        let outcome: Outcome
        if let ton = wallet.legacyTonAccount {
            let key = try? TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: words).publicKey.data
            outcome = key == ton.publicKey ? .verified : .mismatch
        } else {
            outcome = verifyBip39(words.joined(separator: " "), wallet: wallet)
        }
        guard outcome == .verified else {
            return outcome
        }
        evidence.record(walletId: wallet.metaId, tags: tags)
        return .verified
    }

    private func verifyBip39(_ phrase: String, wallet: MetaAccountModel) -> Outcome {
        guard let mnemonic = try? IRMnemonicCreator().mnemonic(fromList: phrase) else {
            return .mismatch
        }
        let entropy = mnemonic.entropy()

        // Restoring needs the paths too; only the standard ones are known without asking.
        let substratePath: String?
        let ethereumPath: String?
        do {
            substratePath = try keystore.fetchDeriviationForAddress(KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId))
            ethereumPath = try keystore.fetchDeriviationForAddress(KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId))
        } catch {
            return .unavailable
        }
        guard (substratePath ?? "").isEmpty,
              ethereumPath == nil || ethereumPath == DerivationPathConstants.defaultEthereum
        else {
            return .customPath
        }

        let derivation = MetaAccountOperationFactory(keystore: InMemoryKeychain())
        var checked = 0
        if let publicKey = wallet.substratePublicKey,
           let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType) {
            guard (try? derivation.entropyReproducesPublicKey(
                entropy, derivationPath: "", cryptoType: cryptoType, publicKey: publicKey
            )) == true else {
                return .mismatch
            }
            checked += 1
        }
        if let address = wallet.ethereumAddress, wallet.ethereumPublicKey != nil {
            let derived = try? derivation.publicKeyForExportEntropy(
                entropy,
                derivationPath: ethereumPath ?? DerivationPathConstants.defaultEthereum,
                cryptoType: .ecdsa,
                ethereumBased: true
            ).ethereumAddressFromPublicKey()
            guard derived == address else {
                return .mismatch
            }
            checked += 1
        }
        // Every universal account the wallet stores must come from these words (no password).
        let secret = UniversalWalletSecret(mnemonic: mnemonic.toString(), passphrase: "")
        for slot in UniversalWalletSlot.allCases {
            guard let account = slot.storedAccount(in: wallet) else {
                continue
            }
            guard (try? slot.publicKey(for: secret)) == account.publicKey else {
                return .mismatch
            }
            checked += 1
        }
        return checked > 0 ? .verified : .mismatch
    }

    /// The wallet's legacy wallet-secret tags, from attributes only; nil when unreadable or when a
    /// tag starting with its id is not a known wallet tag.
    private func walletTags(_ wallet: MetaAccountModel) -> [String]? {
        guard let all = try? inventory.applicationTags(),
              WalletSecretTag.unknownTags(in: all, of: wallet.metaId).isEmpty else {
            return nil
        }
        return all.filter { WalletSecretTag.belongs($0, to: wallet.metaId) }.sorted()
    }
}
