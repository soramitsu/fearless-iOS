import Foundation
import SoraKeystore
import SSFCrypto
import SSFModels

/// The words and BIP39 passphrase one universal account was derived from. A wallet whose
/// Substrate (else Ethereum) path ends in `///password` derives Bitcoin, Solana, TON and Taira
/// with that password; earlier releases used the words alone and a wallet keeps such an account
/// until it switches it, so readers match the stored key against both candidates.
struct UniversalWalletSecret: Equatable {
    let mnemonic: String
    let passphrase: String

    /// The password-protected account first, then the one the words alone open.
    var candidates: [UniversalWalletSecret] {
        passphrase.isEmpty ? [self] : [self, UniversalWalletSecret(mnemonic: mnemonic, passphrase: "")]
    }
}

enum UniversalWalletPassphrase {
    /// The password after `///` in the Substrate path, else in the Ethereum path; empty when
    /// neither has one. It is returned as typed: derivation NFKD-normalises it, as BIP39 does.
    static func resolve(substrateDerivationPath: String?, ethereumDerivationPath: String?) -> String {
        password(in: substrateDerivationPath, factory: SubstrateJunctionFactory())
            ?? password(in: ethereumDerivationPath, factory: BIP32JunctionFactory())
            ?? ""
    }

    /// The passphrase of a wallet imported from words, read from its stored paths. Both paths
    /// belong to the root entropy, which is the universal root of such a wallet.
    static func stored(metaId: MetaAccountId, keystore: KeystoreProtocol) throws -> String {
        resolve(
            substrateDerivationPath: try keystore.fetchDeriviationForAddress(
                KeystoreTagV2.substrateDerivationTagForMetaId(metaId)
            ),
            ethereumDerivationPath: try keystore.fetchDeriviationForAddress(
                KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)
            )
        )
    }

    private static func password(in path: String?, factory: JunctionFactoryProtocol) -> String? {
        guard let path, !path.isEmpty,
              let password = try? factory.parse(path: path).password,
              !password.isEmpty
        else {
            return nil
        }
        return password
    }
}

/// A universal network that holds one derived account per wallet. Nexus has no row of its
/// own and shows the Taira key; Solana devnet uses the mainnet key.
enum UniversalWalletSlot: String, CaseIterable, Hashable {
    case bitcoinMainnet
    case bitcoinTestnet
    case solana
    case ton
    case taira

    var chainId: ChainModel.Id {
        switch self {
        case .bitcoinMainnet:
            return UniversalWalletRegistry.bitcoinMainnet.chainId
        case .bitcoinTestnet:
            return UniversalWalletRegistry.bitcoinTestnet.chainId
        case .solana:
            return UniversalWalletRegistry.solanaMainnet.chainId
        case .ton:
            return UniversalWalletRegistry.tonMainnetRegistryEntry.chainId
        case .taira:
            return UniversalWalletRegistry.taira.chainId
        }
    }

    var networkName: String {
        switch self {
        case .bitcoinMainnet:
            return UniversalWalletRegistry.bitcoinMainnet.name
        case .bitcoinTestnet:
            return UniversalWalletRegistry.bitcoinTestnet.name
        case .solana:
            return UniversalWalletRegistry.solanaMainnet.name
        case .ton:
            return UniversalWalletRegistry.tonMainnetRegistryEntry.displayName
        case .taira:
            return UniversalWalletRegistry.tairaRegistryEntry.displayName
        }
    }

    var cryptoType: CryptoType {
        switch self {
        case .bitcoinMainnet, .bitcoinTestnet:
            return .ecdsa
        case .solana, .ton, .taira:
            return .ed25519
        }
    }

    /// The slot whose stored key `chainId` uses, including the networks that share a key.
    init?(chainId: ChainModel.Id) {
        switch UniversalWalletChainAccountSupport.canonicalChainId(for: chainId) {
        case UniversalWalletRegistry.bitcoinMainnet.chainId:
            self = .bitcoinMainnet
        case UniversalWalletRegistry.bitcoinTestnet.chainId:
            self = .bitcoinTestnet
        case UniversalWalletRegistry.solanaMainnet.chainId,
             UniversalWalletRegistry.solanaDevnet.chainId:
            self = .solana
        case UniversalWalletRegistry.tonMainnetRegistryEntry.chainId:
            self = .ton
        case UniversalWalletRegistry.taira.chainId,
             UniversalWalletRegistry.nexus.chainId:
            self = .taira
        default:
            return nil
        }
    }

    func publicKey(for secret: UniversalWalletSecret) throws -> Data {
        switch self {
        case .bitcoinMainnet:
            return try BitcoinKeyDerivation.deriveAccount(
                mnemonic: secret.mnemonic, passphrase: secret.passphrase, network: .mainnet
            ).publicKey
        case .bitcoinTestnet:
            return try BitcoinKeyDerivation.deriveAccount(
                mnemonic: secret.mnemonic, passphrase: secret.passphrase, network: .testnet
            ).publicKey
        case .solana:
            return try SolanaKeyDerivation.deriveAccount(
                mnemonic: secret.mnemonic, passphrase: secret.passphrase
            ).publicKey
        case .ton:
            return try TonKeyDerivation.deriveAccount(
                mnemonic: secret.mnemonic, passphrase: secret.passphrase
            ).publicKey
        case .taira:
            return try IrohaKeyDerivation.deriveAccount(
                mnemonic: secret.mnemonic, passphrase: secret.passphrase
            ).publicKey
        }
    }

    /// The account this slot holds in `wallet`, when it is a well-formed derived account.
    func storedAccount(in wallet: MetaAccountModel) -> ChainAccountModel? {
        wallet.chainAccounts.first { account in
            guard UniversalWalletChainAccountSupport.chainId(account.chainId, matches: chainId) else {
                return false
            }
            switch self {
            case .bitcoinMainnet, .bitcoinTestnet:
                return UniversalWalletChainAccountSupport.isValidBitcoinAccount(account, chainId: chainId)
            case .solana:
                return UniversalWalletChainAccountSupport.isValidSolanaAccount(account, chainId: chainId)
            case .taira:
                return UniversalWalletChainAccountSupport.isValidTairaAccount(account)
            case .ton:
                return account.publicKey.count == 32 && account.accountId == account.publicKey
            }
        }
    }

    /// The candidate of `secret` whose key this slot stores, if any.
    func matchingSecret(_ secret: UniversalWalletSecret, publicKey: Data) -> UniversalWalletSecret? {
        secret.candidates.first { (try? self.publicKey(for: $0)) == publicKey }
    }
}

/// Which account a missing universal network of a password wallet gets.
enum UniversalWalletPasswordEnrollment: Equatable {
    /// Words this app just generated: nothing can have used the accounts they open alone.
    case generated
    /// Imported or restored words. These networks keep the account the words open without the
    /// password (it holds funds or could not be checked); the others use the password.
    case imported(keepingNoPassword: Set<UniversalWalletSlot>)

    /// Without a funds check every account the words open alone is kept.
    static let unchecked = imported(keepingNoPassword: Set(UniversalWalletSlot.allCases))

    func passphrase(for slot: UniversalWalletSlot, password: String) -> String {
        switch self {
        case .generated:
            return password
        case let .imported(keepingNoPassword):
            return keepingNoPassword.contains(slot) ? "" : password
        }
    }

    /// Networks an import or enrolment of a password wallet keeps watching
    /// (`UniversalWalletWatchedAccountsStore`). Imported words may have been used with or without
    /// the password elsewhere, so whichever account a network did not get stays watched: the old
    /// one where the check found it empty, the protected one where the old one was kept.
    func watchedAfterCheck(_ slots: Set<UniversalWalletSlot>, password: String) -> Set<UniversalWalletSlot> {
        guard case .imported = self, !password.isEmpty else {
            return []
        }
        return slots
    }

    /// Keeps the account the words alone open where it holds funds or could not be checked.
    static func probed(_ funds: [UniversalWalletSlot: UniversalWalletFundsState]) -> UniversalWalletPasswordEnrollment {
        imported(keepingNoPassword: Set(UniversalWalletSlot.allCases.filter { funds[$0] != .empty }))
    }
}

extension UniversalWalletAccountProvisioning {
    /// What the app adds at start to a wallet created by any earlier release: missing networks
    /// only, never a replacement. A password wallet's missing network gets the account its
    /// password protects unless the one the words alone open holds funds or cannot be checked.
    static func enrollingMissingAccounts(
        in wallet: MetaAccountModel,
        root: UniversalWalletSecret,
        probe: @autoclosure () -> UniversalWalletFundsProbing,
        watchedAccounts: UniversalWalletWatchedAccountsStore = UniversalWalletWatchedAccountsStore()
    ) async throws -> MetaAccountModel {
        var enrollment = UniversalWalletPasswordEnrollment.unchecked
        let missingSlots = missingSlots(in: wallet)
        if !root.passphrase.isEmpty, !missingSlots.isEmpty {
            enrollment = .probed(await probe().noPasswordFunds(mnemonic: root.mnemonic, slots: missingSlots))
        }
        let enrolled = try addingMissingAppOwnedAccounts(
            to: wallet,
            mnemonic: root.mnemonic,
            passphrase: root.passphrase,
            enrollment: enrollment
        )
        watchedAccounts.watch(
            enrollment.watchedAfterCheck(missingSlots, password: root.passphrase),
            in: wallet.metaId
        )
        return enrolled
    }
}
