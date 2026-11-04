import Foundation
import IrohaCrypto
import SoraKeystore
import SSFCrypto
import SSFModels

/// How a Fearless client turned the `///password` of a Substrate derivation path into the salt of the
/// account's mini secret (`docs/substrate-password-vectors.json`):
/// - `nfkd`: NFKD(password), as this app always has and as BIP39 specifies. New accounts use it.
/// - `nfc`: NFC(password), as the Fearless browser extension 4.2 did.
/// - `asTyped`: the password exactly as entered, as the browser extension 3.0 and earlier did.
/// The rules agree for ASCII passwords. An import may open an account the extension made under an
/// earlier rule; nothing stores which rule a wallet uses, so every check that re-derives a stored key
/// accepts whichever rule reproduces it.
enum SubstratePasswordRule: CaseIterable {
    case nfkd
    case nfc
    case asTyped

    func saltPassword(_ password: String) -> String {
        switch self {
        case .nfkd:
            return password.decomposedStringWithCompatibilityMapping
        case .nfc:
            return password.precomposedStringWithCanonicalMapping
        case .asTyped:
            return password
        }
    }

    /// The rules that salt the password of a Substrate `derivationPath` differently, `.nfkd` first;
    /// only `.nfkd` when the path has no password or cannot be read.
    static func distinctRules(forSubstrateDerivationPath derivationPath: String) -> [SubstratePasswordRule] {
        guard !derivationPath.isEmpty,
              let password = try? SubstrateJunctionFactory().parse(path: derivationPath).password,
              !password.isEmpty else {
            return [.nfkd]
        }

        // Swift compares strings by canonical equivalence, so the salts are compared as UTF-8.
        var salts: [Data] = []
        return allCases.filter { rule in
            let salt = Data(rule.saltPassword(password).utf8)
            guard !salts.contains(salt) else {
                return false
            }
            salts.append(salt)
            return true
        }
    }

    /// The 32-byte mini secret of `mnemonic` with `password` read by this rule. `.nfkd` is the
    /// derivation the import has always used (`SeedFactory`); the others salt with the bytes as read.
    func miniSeed(mnemonic: IRMnemonicProtocol, password: String) throws -> Data {
        if self == .nfkd {
            return try SeedFactory().deriveSeed(from: mnemonic.toString(), password: password).seed.miniSeed
        }
        let salt = Data(("mnemonic" + saltPassword(password)).utf8)
        return try IRBIP39KeyDeriviation().deriveKey(from: mnemonic.entropy(), salt: salt, length: 64).miniSeed
    }
}

/// The Substrate account BIP39 words and a derivation path open when the path's password is read by `rule`.
struct SubstratePasswordAccount {
    let rule: SubstratePasswordRule
    let publicKey: Data
    /// Generic SS58 (prefix 42), the form a Google Drive backup files its wallet under.
    let address: String
}

extension SubstratePasswordRule {
    /// One account per rule that reads the path's password differently, the current rule first.
    /// A single entry means every Fearless app opens the same account. Nothing is written.
    static func accounts(
        mnemonic: IRMnemonicProtocol,
        derivationPath: String,
        cryptoType: CryptoType
    ) throws -> [SubstratePasswordAccount] {
        let derivation = MetaAccountOperationFactory(keystore: Keychain())
        return try distinctRules(forSubstrateDerivationPath: derivationPath).map { rule in
            let publicKey = try derivation.publicKeyForExportEntropy(
                mnemonic.entropy(),
                derivationPath: derivationPath,
                cryptoType: cryptoType,
                ethereumBased: false,
                passwordRule: rule
            )
            return try SubstratePasswordAccount(
                rule: rule,
                publicKey: publicKey,
                address: publicKey.toAddress(using: .substrate(42))
            )
        }
    }
}
