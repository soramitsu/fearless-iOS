import Foundation
import SSFCloudStorage
import SSFModels
import SSFUtils

/// The accounts one Google Drive backup can hold.
///
/// The backup file every Fearless app reads and writes (SSFCloudStorage `OpenBackupAccount`,
/// Android `EncryptedBackupAccount`) has one Substrate slot and one Ethereum slot for the
/// wallet's own keys: a recovery phrase with both derivation paths, a raw seed for each, or a
/// JSON file for each. It has no field for an account imported for one network or for a TON
/// phrase, and every restore needs the Substrate slot.
///
/// A wallet uses its own Substrate account on every Substrate network and its own Ethereum
/// account on every EVM network, so the accounts of any number of networks come down to
/// these two.
struct GoogleDriveBackupContent {
    let substrate: ChainAccountInfo
    let ethereum: ChainAccountInfo?

    var accounts: [ChainAccountInfo] {
        [substrate, ethereum].compactMap { $0 }
    }

    init(wallet: MetaAccountModel, accounts: [ChainAccountInfo]) throws {
        if let reason = Self.unsupportedReason(for: wallet) {
            throw reason
        }

        guard let substrate = accounts.first(where: {
            Self.isWalletOwnAccount($0.account, of: wallet, ethereumBased: false)
        }) else {
            throw BackupCreatePasswordError.incompleteBackupMaterial
        }

        self.substrate = substrate
        ethereum = accounts.first(where: {
            Self.isWalletOwnAccount($0.account, of: wallet, ethereumBased: true)
        })
    }

    /// Why no Google Drive backup can restore this wallet, or nil if one can.
    static func unsupportedReason(for wallet: MetaAccountModel) -> BackupCreatePasswordError? {
        guard wallet.substratePublicKey == nil || wallet.substrateAccountId == nil else {
            return nil
        }

        return wallet.legacyTonAccount != nil
            ? .nativeTonWalletNotSupported
            : .walletWithoutSubstrateAccount
    }

    /// Accounts of this wallet that a backup of its own keys does not bring back: accounts
    /// imported for one network. The Bitcoin, Solana, BIP39 TON and Taira accounts are derived from the
    /// wallet's own phrase or seed and are derived again when the backup is restored; the few
    /// whose keys came from other material are found once the backup is written, see
    /// `appOwnedAccountsNotRestored(from:by:)`.
    static func accountsNotRestored(from wallet: MetaAccountModel) -> [ChainAccountModel] {
        wallet.chainAccounts
            .filter { !isAppOwned($0) }
            .sorted { $0.chainId < $1.chainId }
    }

    /// The wallet's Bitcoin, Solana, BIP39 TON and Taira accounts that restoring `backup` does not give
    /// back.
    ///
    /// A restore derives these accounts again from the backup's recovery phrase, or from its
    /// Substrate seed for a seed backup, and derives none from JSON files
    /// (`MetaAccountOperationFactory.newMetaAccountOperation` and
    /// `UniversalWalletAccountProvisioning`). The device derived
    /// them from the stored phrase, or from the stored seed of a wallet imported from a seed,
    /// so a backup that had to use other material than that restores the wallet's Substrate
    /// and Ethereum accounts but another Bitcoin or Solana account.
    static func appOwnedAccountsNotRestored(
        from wallet: MetaAccountModel,
        by backup: OpenBackupAccount
    ) -> [ChainAccountModel] {
        let secret = appOwnedAccountsSecret(restoredFrom: backup)

        return wallet.chainAccounts
            .filter { isAppOwned($0) && !isDerived($0, from: secret) }
            .sorted { $0.chainId < $1.chainId }
    }

    /// "Network: address" for an account of `appOwnedAccountsNotRestored(from:by:)`.
    static func displayLine(for account: ChainAccountModel) -> String {
        let network = UniversalWalletRegistry.bitcoinNetwork(for: account.chainId)?.name
            ?? UniversalWalletRegistry.solanaNetwork(for: account.chainId)?.name
            ?? (isTon(account) ? UniversalWalletRegistry.tonMainnetRegistryEntry.displayName
                : UniversalWalletRegistry.tairaRegistryEntry.displayName)
        let address = UniversalWalletChainAccountSupport.address(for: account.chainId, publicKey: account.publicKey)
            ?? account.accountId.toHex(includePrefix: true)
        return "\(network): \(address)"
    }

    /// Accounts the app derives from the wallet's own phrase or seed
    /// (`UniversalWalletAccountProvisioning`): Bitcoin, Solana mainnet, BIP39 TON and Taira.
    private static func isAppOwned(_ account: ChainAccountModel) -> Bool {
        UniversalWalletRegistry.bitcoinNetwork(for: account.chainId) != nil ||
            UniversalWalletRegistry.solanaNetwork(for: account.chainId) == UniversalWalletRegistry.solanaMainnet ||
            isTon(account) ||
            UniversalWalletChainAccountSupport.chainId(
                account.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
    }

    private static func isTon(_ account: ChainAccountModel) -> Bool {
        UniversalWalletChainAccountSupport.chainId(
            account.chainId, matches: UniversalWalletRegistry.tonMainnetRegistryEntry.chainId
        )
    }

    /// The phrase a restore of `backup` derives the Bitcoin, Solana, BIP39 TON and Taira accounts from, in
    /// the order `BackupPasswordPresenter` reads the backup, with the wallet password its paths carry.
    private static func appOwnedAccountsSecret(restoredFrom backup: OpenBackupAccount) -> UniversalWalletSecret? {
        let types = backup.backupAccountType ?? []
        if types.contains(.passphrase) {
            return backup.passphrase.map {
                UniversalWalletSecret(
                    mnemonic: $0,
                    passphrase: UniversalWalletPassphrase.resolve(
                        substrateDerivationPath: backup.substrateDerivationPath,
                        ethereumDerivationPath: backup.ethDerivationPath
                    )
                )
            }
        }
        guard
            types.contains(.seed),
            let substrateSeed = backup.encryptedSeed?.substrateSeed,
            let walletSeed = try? Data(hexStringSSF: substrateSeed),
            let mnemonic = try? UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
        else {
            return nil
        }
        return UniversalWalletSecret(mnemonic: mnemonic, passphrase: "")
    }

    /// A restore gives back the account the password protects or, where it holds funds, the one
    /// the words alone open, so either counts as restored.
    private static func isDerived(_ account: ChainAccountModel, from secret: UniversalWalletSecret?) -> Bool {
        guard let secret, let slot = UniversalWalletSlot(chainId: account.chainId) else {
            return false
        }

        if slot == .ton {
            // A matching public key alone does not prove that a malformed stored row
            // can be recovered. Keep independent or inconsistent identities in the warning.
            guard account.publicKey.count == 32,
                  account.accountId == account.publicKey,
                  account.cryptoType == CryptoType.ed25519.rawValue,
                  !account.ethereumBased else {
                return false
            }
        }

        return slot.matchingSecret(secret, publicKey: account.publicKey) != nil
    }

    private static func isWalletOwnAccount(
        _ account: ChainAccountResponse,
        of wallet: MetaAccountModel,
        ethereumBased: Bool
    ) -> Bool {
        guard
            !account.isChainAccount,
            account.legacyTonAddress == nil,
            account.isEthereumBased == ethereumBased
        else {
            return false
        }

        return ethereumBased
            ? account.accountId == wallet.ethereumAddress
            : account.accountId == wallet.substrateAccountId
    }
}
