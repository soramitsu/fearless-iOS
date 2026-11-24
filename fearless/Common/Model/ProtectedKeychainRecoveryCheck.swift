import Foundation
import IrohaCrypto
import SoraKeystore
import SSFModels
import TonSwift

/// Lets the owner of a wallet an earlier release made show they still have its recovery phrase,
/// so the wallet may move to protected storage (design doc 3.5, precondition 4; 3.9). Offered once
/// per wallet and only while the flag is on; skipping leaves the wallet exactly as it is.
///
/// Evidence is recorded only when the typed phrase, with the standard derivation paths, reproduces
/// **every** stored item of the wallet byte for byte (exactly what the released import writes) and
/// every public key the wallet stores; the evidence holds a digest of each item, so an item that
/// changes later is no longer covered. Anything else (an item from another backup, a child seed an
/// older release kept under a root tag, a custom path or password, an account imported on its own)
/// records nothing. The stored phrase is never shown.
final class ProtectedKeychainRecoveryCheck {
    enum Outcome: Equatable {
        /// Every stored item and public key matched: evidence recorded for those items.
        case verified
        /// The words are not this wallet's phrase.
        case mismatch
        /// The wallet uses a custom derivation path or password: it stays as it is.
        case customPath
        /// It cannot be proved here (keychain unreadable, the flag went off, the check was closed,
        /// an item the phrase does not write, an account imported on its own): it stays as it is.
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
        keystore: KeystoreProtocol = Keychain(routed: false),
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

    /// Public data only (the attribute inventory; no secret is read): the flag is on, the wallet was
    /// never offered the check, **none** of its items has evidence, and its items are the root items
    /// of one phrase (a BIP39 phrase, or a released native TON phrase) with no account of its own.
    func shouldOffer(_ wallet: MetaAccountModel) -> Bool {
        guard isEnabled(), !wasOffered(wallet.metaId), let tags = walletTags(wallet),
              Self.isPhraseWallet(wallet, tags: tags)
        else {
            return false
        }
        guard !tags.contains(where: { evidence.covers(tag: $0, walletId: wallet.metaId) }) else {
            return false
        }
        if wallet.legacyTonAccount != nil {
            return true
        }
        return wallet.substratePublicKey != nil || wallet.ethereumPublicKey != nil
    }

    /// Recorded when the offer is shown: it is never shown for this wallet again, however it closes.
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

    /// Checks `phrase` against `wallet` and records evidence on a match. Slow (key derivation): call
    /// it off the main thread. It holds `WalletSecretWriteLock` from reading the items to recording,
    /// so no wallet-secret write lands in between; `isCancelled` and the flag are checked again
    /// right before recording.
    func verify(
        phrase: String,
        wallet: MetaAccountModel,
        isCancelled: @escaping () -> Bool = { false }
    ) -> Outcome {
        WalletSecretWriteLock.perform {
            guard isEnabled(), let tags = walletTags(wallet), Self.isPhraseWallet(wallet, tags: tags) else {
                return .unavailable
            }
            var stored: [String: Data] = [:]
            do {
                for tag in tags {
                    stored[tag] = try keystore.fetchKey(for: tag)
                }
            } catch {
                return .unavailable
            }

            let outcome: Outcome
            if let ton = wallet.legacyTonAccount {
                outcome = Self.verifyTon(phrase, account: ton, walletId: wallet.metaId, stored: stored)
            } else {
                outcome = Self.verifyBip39(phrase, wallet: wallet, stored: stored)
            }
            guard outcome == .verified else {
                return outcome
            }
            guard !isCancelled(), isEnabled() else {
                return .unavailable
            }
            evidence.record(walletId: wallet.metaId, items: stored)
            return .verified
        }
    }

    static func words(_ phrase: String) -> [String] {
        phrase.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    /// Root items of one phrase only: a phrase is stored, no account has items of its own, every
    /// account the wallet lists is a universal account of its root, and it is not a raw-seed wallet.
    private static func isPhraseWallet(_ wallet: MetaAccountModel, tags: [String]) -> Bool {
        let root = { (suffix: String) in wallet.metaId + suffix }
        guard !tags.isEmpty,
              tags.allSatisfy({ WalletSecretTag.accountScope(of: $0, walletId: wallet.metaId) == "" }),
              tags.contains(root("-entropy")),
              !tags.contains(root("-universalWalletSecretSource")),
              wallet.chainAccounts.allSatisfy({ UniversalWalletSlot(chainId: $0.chainId) != nil })
        else {
            return false
        }
        if wallet.legacyTonAccount != nil {
            return Set(tags).isSubset(of: [root("-entropy"), root("-tonSecretKey")])
        }
        return true
    }

    /// A released native TON wallet: the typed words, as typed or normalized (both are forms the
    /// native import accepts), must give the wallet's key; the stored phrase and stored signing key
    /// must be that same key.
    private static func verifyTon(
        _ phrase: String,
        account: LegacyTonAccount,
        walletId: MetaAccountId,
        stored: [String: Data]
    ) -> Outcome {
        let texts = [phrase, phrase.trimmingCharacters(in: .whitespacesAndNewlines), phrase.lowercased()]
        let candidates = texts.flatMap { (try? LegacyTonMnemonic.importCandidates($0)) ?? [] }
        guard let candidate = candidates.first(where: { $0.publicKey == account.publicKey }),
              let typed = try? TonSwift.Mnemonic.mnemonicToPrivateKey(
                  mnemonicArray: candidate.mnemonic.allWords()
              ).privateKey.data
        else {
            return .mismatch
        }
        let phraseTag = KeystoreTagV2.entropyTagForMetaId(walletId)
        let keyTag = KeystoreTagV2.tonSecretKeyTagForMetaId(walletId)
        guard let storedPhrase = stored[phraseTag],
              let storedWords = try? account.mnemonic(from: storedPhrase).allWords(),
              (try? TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: storedWords))?.privateKey.data == typed,
              stored[keyTag] == nil || stored[keyTag] == typed,
              Set(stored.keys).isSubset(of: [phraseTag, keyTag])
        else {
            return .unavailable
        }
        return .verified
    }

    /// A BIP39 wallet: the typed phrase must be the stored one, and every other stored item must be
    /// exactly what the released import writes for it with the standard paths.
    private static func verifyBip39(_ phrase: String, wallet: MetaAccountModel, stored: [String: Data]) -> Outcome {
        guard let mnemonic = try? IRMnemonicCreator().mnemonic(fromList: words(phrase).joined(separator: " ")) else {
            return .mismatch
        }
        let metaId = wallet.metaId
        let entropy = mnemonic.entropy()
        guard let storedEntropy = stored[KeystoreTagV2.entropyTagForMetaId(metaId)] else {
            return .unavailable
        }
        guard storedEntropy == entropy else {
            return .mismatch
        }

        // Restoring needs the paths too; only the standard ones are known without asking.
        let substratePath = stored[KeystoreTagV2.substrateDerivationTagForMetaId(metaId)]
        let ethereumPath = stored[KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)]
        let standardEthereum = DerivationPathConstants.defaultEthereum
        guard substratePath == nil || substratePath?.isEmpty == true,
              ethereumPath == nil || ethereumPath == Data(standardEthereum.utf8)
        else {
            return .customPath
        }

        let derivation = MetaAccountOperationFactory(keystore: InMemoryKeychain())
        guard let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType),
              let expected = try? derivation.rootItemsForMnemonicImport(
                  entropy: entropy, substratePath: "", ethereumPath: standardEthereum, cryptoType: cryptoType
              )
        else {
            return .unavailable
        }

        // Every stored item, byte for byte, is one this phrase writes.
        for (tag, bytes) in stored {
            guard let suffix = WalletSecretTag.suffixes.first(where: { tag == metaId + $0 }),
                  expected[suffix] == bytes
            else {
                return .unavailable
            }
        }

        // And every public key the wallet stores comes from it.
        if let publicKey = wallet.substratePublicKey {
            guard (try? derivation.entropyReproducesPublicKey(
                entropy, derivationPath: "", cryptoType: cryptoType, publicKey: publicKey
            )) == true else {
                return .unavailable
            }
        }
        if wallet.ethereumAddress != nil || wallet.ethereumPublicKey != nil {
            guard let derived = try? derivation.publicKeyForExportEntropy(
                entropy, derivationPath: standardEthereum, cryptoType: .ecdsa, ethereumBased: true
            ), let derivedAddress = try? derived.ethereumAddressFromPublicKey() else {
                return .unavailable
            }
            if let address = wallet.ethereumAddress, address != derivedAddress {
                return .unavailable
            }
            // A key stored in another encoding still names the same address.
            if let publicKey = wallet.ethereumPublicKey, publicKey != derived,
               (try? publicKey.ethereumAddressFromPublicKey()) != derivedAddress {
                return .unavailable
            }
        }
        let secret = UniversalWalletSecret(mnemonic: mnemonic.toString(), passphrase: "")
        for slot in UniversalWalletSlot.allCases {
            guard let account = slot.storedAccount(in: wallet) else {
                continue
            }
            guard (try? slot.publicKey(for: secret)) == account.publicKey else {
                return .unavailable
            }
        }
        return .verified
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
