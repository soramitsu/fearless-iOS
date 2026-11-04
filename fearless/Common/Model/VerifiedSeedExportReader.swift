import Foundation
import SoraKeystore
import SSFModels

enum VerifiedSeedExportError: Error, Equatable {
    case missingSeed
    case seedDoesNotMatchAccount
}

extension VerifiedSeedExportError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let languages = locale?.rLanguages

        switch self {
        case .missingSeed:
            return ErrorContent(
                title: R.string.localizable.exportSeedUnavailableTitle(preferredLanguages: languages),
                message: R.string.localizable.exportSeedMissingMessage(preferredLanguages: languages)
            )
        case .seedDoesNotMatchAccount:
            return ErrorContent(
                title: R.string.localizable.exportSeedUnavailableTitle(preferredLanguages: languages),
                message: R.string.localizable.exportSeedMismatchMessage(preferredLanguages: languages)
            )
        }
    }
}

struct VerifiedSeedExport: Equatable {
    let seed: Data
    let derivationPath: String?
}

protocol VerifiedSeedExportReading {
    func fetchSeed(
        metaId: MetaAccountId,
        accountId: AccountId?,
        publicKey: Data,
        cryptoType: CryptoType,
        ethereumBased: Bool
    ) throws -> VerifiedSeedExport
}

/// Returns a raw seed for export only when importing it recreates the account it is shown for.
///
/// The 4.0.x releases stored the seed of every imported per-chain Substrate account under the
/// wallet-level tag, replacing the wallet's own seed. The stored seed can therefore belong to
/// another account. Showing it would hand the user a backup that restores a different address.
/// Nothing is written or removed here; a seed that fails the check is simply not shown.
final class VerifiedSeedExportReader: VerifiedSeedExportReading {
    private let keystore: KeystoreProtocol
    private let derivation: MetaAccountOperationFactory

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
        derivation = MetaAccountOperationFactory(keystore: keystore)
    }

    func fetchSeed(
        metaId: MetaAccountId,
        accountId: AccountId?,
        publicKey: Data,
        cryptoType: CryptoType,
        ethereumBased: Bool
    ) throws -> VerifiedSeedExport {
        if ethereumBased {
            return try fetchEthereumSeed(metaId: metaId, accountId: accountId, publicKey: publicKey)
        }

        let derivationPath = try keystore.fetchDeriviationForAddress(
            KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId)
        )
        var storedCandidateExists = false

        // 1. The seed stored for this account, with the path it was imported under.
        if let seed = try keystore.loadIfKeyExists(
            KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)
        ) {
            storedCandidateExists = true
            if recreates(publicKey, seed: seed, derivationPath: derivationPath ?? "", cryptoType: cryptoType) {
                return VerifiedSeedExport(seed: seed, derivationPath: derivationPath)
            }
        }

        // 2. The seed the released mnemonic import stored, rebuilt from the account's own entropy.
        if let entropy = try keystore.loadIfKeyExists(
            KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        ) {
            storedCandidateExists = true
            // An import may have opened the account an earlier browser extension made from the
            // path's password (SubstratePasswordRule): the seed is the one that rebuilds it.
            for rule in SubstratePasswordRule.distinctRules(forSubstrateDerivationPath: derivationPath ?? "") {
                if let rebuilt = try? derivation.exportSeedForEntropy(
                    entropy, derivationPath: derivationPath ?? "", cryptoType: cryptoType, passwordRule: rule
                ), rebuilt.publicKey == publicKey {
                    return VerifiedSeedExport(seed: rebuilt.seed, derivationPath: derivationPath)
                }
            }
        }

        // 3. The 4.0.x releases kept a per-chain account's seed only under the wallet-level
        // tag. It belongs to this account only if it recreates it with the account's path.
        if accountId != nil, let seed = try keystore.loadIfKeyExists(
            KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: nil)
        ) {
            storedCandidateExists = true
            if recreates(publicKey, seed: seed, derivationPath: derivationPath ?? "", cryptoType: cryptoType) {
                return VerifiedSeedExport(seed: seed, derivationPath: derivationPath)
            }
        }

        // 4. For ed25519 and ECDSA the stored secret key is the already derived seed,
        // so it is shown without a path.
        if cryptoType.supportsSeedFromSecretKey, let secretKey = try keystore.loadIfKeyExists(
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)
        ) {
            storedCandidateExists = true
            if recreates(publicKey, seed: secretKey, derivationPath: "", cryptoType: cryptoType) {
                return VerifiedSeedExport(seed: secretKey, derivationPath: nil)
            }
        }

        throw storedCandidateExists
            ? VerifiedSeedExportError.seedDoesNotMatchAccount
            : VerifiedSeedExportError.missingSeed
    }

    private func fetchEthereumSeed(
        metaId: MetaAccountId,
        accountId: AccountId?,
        publicKey: Data
    ) throws -> VerifiedSeedExport {
        guard let secretKey = try keystore.loadIfKeyExists(
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
        ) else {
            throw VerifiedSeedExportError.missingSeed
        }

        // Compare addresses, so a compressed and an uncompressed form of one key are equal.
        guard
            let derivedPublicKey = try? derivation.publicKeyForExportSeed(
                secretKey, derivationPath: "", cryptoType: .ecdsa, ethereumBased: true
            ),
            let derivedAddress = try? derivedPublicKey.ethereumAddressFromPublicKey(),
            let expectedAddress = try? publicKey.ethereumAddressFromPublicKey(),
            derivedAddress == expectedAddress
        else {
            throw VerifiedSeedExportError.seedDoesNotMatchAccount
        }

        //  We shouldn't show derivation path for ethereum seed. So just provide nil to hide it
        return VerifiedSeedExport(seed: secretKey, derivationPath: nil)
    }

    private func recreates(
        _ publicKey: Data,
        seed: Data,
        derivationPath: String,
        cryptoType: CryptoType
    ) -> Bool {
        let derivedPublicKey = try? derivation.publicKeyForExportSeed(
            seed, derivationPath: derivationPath, cryptoType: cryptoType, ethereumBased: false
        )

        return derivedPublicKey == publicKey
    }
}
