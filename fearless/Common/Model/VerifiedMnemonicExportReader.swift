import Foundation
import IrohaCrypto
import SoraKeystore
import SSFModels
import SSFUtils

/// A proof can only be made after each exported phrase recreates its captured account.
struct VerifiedMnemonicBackup {
    private let wallet: MetaAccountModel
    private let entropy: Data

    fileprivate init(wallet: MetaAccountModel, entropy: Data) {
        self.wallet = wallet
        self.entropy = entropy
    }

    func covers(_ mnemonic: IRMnemonicProtocol, wallet: MetaAccountModel) -> Bool {
        self.wallet == wallet && entropy == mnemonic.entropy()
    }
}

struct VerifiedMnemonicExport {
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let wallet: MetaAccountModel
    let info: ChainAccountInfo

    fileprivate init(
        mnemonic: IRMnemonicProtocol,
        derivationPath: String?,
        wallet: MetaAccountModel,
        info: ChainAccountInfo
    ) {
        self.mnemonic = mnemonic
        self.derivationPath = derivationPath
        self.wallet = wallet
        self.info = info
    }
}

/// Reads existing material and uses the released import recipes. Never mutates stored secrets.
final class VerifiedMnemonicExportReader {
    private let keystore: KeystoreProtocol
    private let derivation: MetaAccountOperationFactory

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
        derivation = MetaAccountOperationFactory(keystore: keystore)
    }

    func fetch(wallet: MetaAccountModel, info: ChainAccountInfo) throws -> VerifiedMnemonicExport {
        let account = info.account
        guard
            account.walletId == wallet.metaId, account.chainId == info.chain.chainId,
            account.isEthereumBased == info.chain.isEthereumBased, belongsToWallet(account, wallet: wallet) else {
            throw UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet
        }
        let accountId = account.isChainAccount ? account.accountId : nil
        if let legacy = wallet.legacyTonAccount, info.chain.isTonCompatibilityChain, accountId == nil {
            let stored = try keystore.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
            let mnemonic = try legacy.mnemonic(from: stored)
            return VerifiedMnemonicExport(mnemonic: mnemonic, derivationPath: nil, wallet: wallet, info: info)
        }
        let universal = account.isChainAccount && UniversalWalletChainAccountSupport
            .isUniversalWalletChain(info.chain.chainId)
        if universal {
            return try fetchUniversal(wallet: wallet, info: info)
        }
        let tag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId)
        let entropy: Data
        if let stored = try keystore.loadIfKeyExists(tag) {
            entropy = stored
        } else {
            throw UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet
        }
        let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
        let pathTag = account.isEthereumBased
            ? KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: accountId)
            : KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)
        let storedPath = try readPath(pathTag)
        let path: String?
        do {
            guard !account.isEthereumBased || storedPath != nil else {
                throw UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet
            }
            let publicKey = try derivation.publicKeyForExportEntropy(
                entropy, derivationPath: storedPath ?? "", cryptoType: account.cryptoType,
                ethereumBased: account.isEthereumBased
            )
            try verify(publicKey: publicKey, account: account)
            path = storedPath
        }
        return VerifiedMnemonicExport(mnemonic: mnemonic, derivationPath: path, wallet: wallet, info: info)
    }

    func backupProof(wallet: MetaAccountModel, exports: [VerifiedMnemonicExport]) -> VerifiedMnemonicBackup? {
        guard
            let first = exports.first, !exports.isEmpty,
            exports.allSatisfy({ $0.wallet == wallet && $0.mnemonic.entropy() == first.mnemonic.entropy() })
        else { return nil }
        let accounts = exports.map(\.info.account)
        guard rootsCovered(wallet: wallet, exports: exports) else { return nil }
        for stored in wallet.chainAccounts {
            guard
                accounts.contains(where: {
                    $0.isChainAccount && $0.accountId == stored.accountId && $0.publicKey == stored.publicKey &&
                        $0.cryptoType.rawValue == stored.cryptoType && $0.isEthereumBased == stored.ethereumBased &&
                        UniversalWalletChainAccountSupport.chainId(stored.chainId, matches: $0.chainId)
                }) else { return nil }
        }
        return VerifiedMnemonicBackup(wallet: wallet, entropy: first.mnemonic.entropy())
    }

    private func rootsCovered(wallet: MetaAccountModel, exports: [VerifiedMnemonicExport]) -> Bool {
        let accounts = exports.map(\.info.account)
        if let publicKey = wallet.substratePublicKey {
            guard
                accounts.contains(where: { !$0.isChainAccount && !$0.isEthereumBased && $0.publicKey == publicKey &&
                        $0.accountId == wallet.substrateAccountId && $0.cryptoType.rawValue == wallet
                        .substrateCryptoType
                }) else { return false }
        } else if wallet.substrateAccountId != nil {
            return false
        }
        if let address = wallet.ethereumAddress {
            guard
                wallet.ethereumPublicKey != nil,
                accounts.contains(where: { !$0.isChainAccount && $0.isEthereumBased && $0.accountId == address })
            else { return false }
        } else if wallet.ethereumPublicKey != nil {
            return false
        }
        if let legacy = wallet.legacyTonAccount {
            guard
                exports
                .contains(where: {
                    !$0.info.account.isChainAccount && $0.info.chain.isTonCompatibilityChain && $0.info.account
                        .publicKey == legacy.publicKey
                }) else { return false }
        }
        return true
    }

    private func belongsToWallet(_ account: ChainAccountResponse, wallet: MetaAccountModel) -> Bool {
        if account.isChainAccount {
            return wallet.chainAccounts.contains {
                $0.accountId == account.accountId && $0.publicKey == account.publicKey &&
                    $0.cryptoType == account.cryptoType.rawValue && $0.ethereumBased == account.isEthereumBased &&
                    (!UniversalWalletChainAccountSupport.isUniversalWalletChain(account.chainId) ||
                        UniversalWalletChainAccountSupport.chainId($0.chainId, matches: account.chainId))
            }
        }
        if
            let legacy = wallet.legacyTonAccount, account.publicKey == legacy.publicKey,
            account.accountId == legacy.serializedAddress, account.cryptoType == .ed25519,
            UniversalWalletChainAccountSupport.chainId(account.chainId, matches: TonChainSelection.mainnetChainId) {
            return true
        }
        if account.isEthereumBased {
            return wallet.ethereumAddress == account.accountId && wallet.ethereumPublicKey == account
                .publicKey && account.cryptoType == .ecdsa
        }
        return wallet.substrateAccountId == account.accountId && wallet.substratePublicKey == account.publicKey &&
            wallet.substrateCryptoType == account.cryptoType.rawValue
    }

    private func readPath(_ tag: String) throws -> String? {
        guard let data = try keystore.loadIfKeyExists(tag) else { return nil }
        guard let path = String(data: data, encoding: .utf8) else {
            throw UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet
        }
        return path
    }

    private func verify(publicKey: Data, account: ChainAccountResponse) throws {
        if account.isEthereumBased {
            let address = try publicKey.ethereumAddressFromPublicKey()
            guard try account.publicKey.ethereumAddressFromPublicKey() == address, account.accountId == address else {
                throw UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet
            }
        } else {
            let accountId = try publicKey.publicKeyToAccountId()
            guard publicKey == account.publicKey, accountId == account.accountId else {
                throw UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet
            }
        }
    }

    private func fetchUniversal(wallet: MetaAccountModel, info: ChainAccountInfo) throws -> VerifiedMnemonicExport {
        // Keep the released root-first recipe, including its explicitly marked raw-seed bridge.
        // A legacy per-account tag cannot replace a root that demonstrably owns this account.
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        // A damaged unrelated root cannot hide a healthy historical child. The
        // fallback below still derives and verifies that child's exact identity.
        // A password wallet's account is either the one its password protects or one an
        // earlier release derived from the words alone; both are the wallet's words. The words
        // alone never restore a protected account, so its path shows the `///password` too.
        if let root = try? provider.rootSecret(for: wallet) {
            let mnemonic = try IRMnemonicCreator().mnemonic(fromList: root.mnemonic)
            for candidate in root.candidates {
                if let path = try? verifyUniversal(
                    mnemonic: mnemonic,
                    passphrase: candidate.passphrase,
                    storedPath: nil,
                    account: info.account
                ) {
                    let shownPath = candidate.passphrase.isEmpty ? path : "\(path)///\(candidate.passphrase)"
                    return VerifiedMnemonicExport(
                        mnemonic: mnemonic, derivationPath: shownPath, wallet: wallet, info: info
                    )
                }
            }
        }
        let accountId = info.account.accountId
        let entropy = try keystore.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId))
        let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
        let path = try readPath(KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId))
        let verifiedPath = try verifyUniversal(
            mnemonic: mnemonic,
            passphrase: "",
            storedPath: path,
            account: info.account
        )
        return VerifiedMnemonicExport(mnemonic: mnemonic, derivationPath: verifiedPath, wallet: wallet, info: info)
    }

    private func verifyUniversal(
        mnemonic: IRMnemonicProtocol,
        passphrase: String,
        storedPath: String?,
        account: ChainAccountResponse
    ) throws -> String {
        let expectedCrypto: CryptoType = UniversalWalletRegistry.bitcoinNetwork(for: account.chainId) == nil
            ? .ed25519
            : .ecdsa
        let result = try universalPublicKey(
            phrase: mnemonic.toString(),
            passphrase: passphrase,
            storedPath: storedPath,
            chainId: account.chainId
        )
        guard
            !account.isEthereumBased, account.cryptoType == expectedCrypto,
            account.publicKey == result.publicKey, account.accountId == result.publicKey else {
            throw UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet
        }
        return result.path
    }

    private func universalPublicKey(
        phrase: String,
        passphrase: String,
        storedPath: String?,
        chainId: ChainModel.Id
    ) throws -> (publicKey: Data, path: String) {
        if let network = UniversalWalletRegistry.bitcoinNetwork(for: chainId) {
            let path = storedPath ?? network.firstReceivePath
            let key = try BitcoinKeyDerivation.deriveKey(
                mnemonic: phrase,
                passphrase: passphrase,
                derivationPath: path,
                network: network == UniversalWalletRegistry.bitcoinMainnet ? .mainnet : .testnet
            )
            return (key.publicKey, path)
        }
        switch UniversalWalletChainAccountSupport.canonicalChainId(for: chainId) {
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaDevnet.chainId:
            let path = storedPath ?? UniversalWalletDerivationPaths.solanaDefault
            let key = try SolanaKeyDerivation.deriveAccount(
                mnemonic: phrase, passphrase: passphrase, derivationPath: path
            )
            return (key.publicKey, path)
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.nexus.chainId:
            let path = storedPath ?? UniversalWalletDerivationPaths.irohaDefault
            let key = try IrohaKeyDerivation.deriveAccount(
                mnemonic: phrase, passphrase: passphrase, derivationPath: path
            )
            return (key.publicKey, path)
        case UniversalWalletRegistry.tonMainnetRegistryEntry.chainId:
            let path = storedPath ?? UniversalWalletDerivationPaths.tonDefault
            let key = try TonKeyDerivation.deriveAccount(mnemonic: phrase, passphrase: passphrase, derivationPath: path)
            return (key.publicKey, path)
        default:
            throw UniversalWalletRootRecoveryError.unsupportedWalletIdentity
        }
    }
}
