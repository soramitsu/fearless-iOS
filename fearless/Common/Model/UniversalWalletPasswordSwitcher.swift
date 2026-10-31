import Foundation
import SSFModels

/// A universal account of a password wallet that the words alone open, with the account the
/// password protects on the same network.
struct UniversalWalletNoPasswordAccount: Equatable {
    let slot: UniversalWalletSlot
    let oldAddress: String
    let newAddress: String
    let newPublicKey: Data

    var networkName: String {
        slot.networkName
    }
}

enum UniversalWalletSwitchOutcome: Equatable {
    case switched
    case stillFunded
    case unchecked
}

/// Gives a password wallet the accounts its password protects in place of ones the words
/// alone open, but only where the old address holds nothing: an old address with funds, or
/// one that cannot be checked, stays until its funds are moved.
final class UniversalWalletPasswordSwitcher {
    private let mnemonicProvider: UniversalWalletRootMnemonicProviding
    private let fundsProbe: () -> UniversalWalletFundsProbing
    private let watchedAccounts: UniversalWalletWatchedAccountsStore

    init(
        mnemonicProvider: UniversalWalletRootMnemonicProviding = KeychainUniversalWalletMnemonicProvider(),
        fundsProbe: @escaping () -> UniversalWalletFundsProbing = { UniversalWalletRemoteFundsProbe.makeDefault() },
        watchedAccounts: UniversalWalletWatchedAccountsStore = UniversalWalletWatchedAccountsStore()
    ) {
        self.mnemonicProvider = mnemonicProvider
        self.fundsProbe = fundsProbe
        self.watchedAccounts = watchedAccounts
    }

    /// Empty for a wallet without a password, or when every account uses it.
    func noPasswordAccounts(in wallet: MetaAccountModel) -> [UniversalWalletNoPasswordAccount] {
        guard let root = try? mnemonicProvider.rootSecret(for: wallet), !root.passphrase.isEmpty else {
            return []
        }
        let wordsOnly = UniversalWalletSecret(mnemonic: root.mnemonic, passphrase: "")

        return UniversalWalletSlot.allCases.compactMap { slot in
            guard
                let account = slot.storedAccount(in: wallet),
                let oldKey = try? slot.publicKey(for: wordsOnly),
                account.publicKey == oldKey,
                let newKey = try? slot.publicKey(for: root),
                newKey != oldKey,
                let oldAddress = UniversalWalletChainAccountSupport.address(for: slot.chainId, publicKey: oldKey),
                let newAddress = UniversalWalletChainAccountSupport.address(for: slot.chainId, publicKey: newKey)
            else {
                return nil
            }
            return UniversalWalletNoPasswordAccount(
                slot: slot,
                oldAddress: oldAddress,
                newAddress: newAddress,
                newPublicKey: newKey
            )
        }
    }

    /// The wallet with every empty old account replaced; nothing is saved here.
    func switching(
        _ accounts: [UniversalWalletNoPasswordAccount],
        in wallet: MetaAccountModel
    ) async -> (wallet: MetaAccountModel, outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome]) {
        var outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome] = [:]
        guard let root = try? mnemonicProvider.rootSecret(for: wallet), !root.passphrase.isEmpty else {
            accounts.forEach { outcomes[$0.slot] = .unchecked }
            return (wallet, outcomes)
        }

        let funds = await fundsProbe().noPasswordFunds(
            mnemonic: root.mnemonic,
            slots: Set(accounts.map(\.slot))
        )
        var chainAccounts = wallet.chainAccounts
        for account in accounts {
            switch funds[account.slot] ?? .unknown {
            case .funded:
                outcomes[account.slot] = .stillFunded
            case .unknown:
                outcomes[account.slot] = .unchecked
            case .empty:
                // Only the exact old account is replaced, keeping its stored network id.
                guard let old = account.slot.storedAccount(in: wallet),
                      (try? account.slot.publicKey(for: root)) == account.newPublicKey else {
                    outcomes[account.slot] = .unchecked
                    continue
                }
                chainAccounts.remove(old)
                chainAccounts.insert(ChainAccountModel(
                    chainId: old.chainId,
                    accountId: account.newPublicKey,
                    publicKey: account.newPublicKey,
                    cryptoType: old.cryptoType,
                    ethereumBased: false
                ))
                outcomes[account.slot] = .switched
            }
        }

        // A deposit can still reach an old address after its check: it stays watched.
        watchedAccounts.watch(Set(outcomes.filter { $0.value == .switched }.keys), in: wallet.metaId)
        let updated = chainAccounts == wallet.chainAccounts ? wallet : wallet.replacingChainAccounts(chainAccounts)
        return (updated, outcomes)
    }
}

/// Records which wallets were shown the notice about accounts their password does not
/// protect, so it appears on its own once per wallet.
final class UniversalWalletPasswordNoticeTracker {
    static let key = "universalWalletPasswordNoticeShownWalletIds"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func wasShown(for walletId: MetaAccountId) -> Bool {
        (userDefaults.stringArray(forKey: Self.key) ?? []).contains(walletId)
    }

    /// An old address took funds again and is back in the wallet: the notice shows once more.
    func reset(for walletId: MetaAccountId) {
        let shown = (userDefaults.stringArray(forKey: Self.key) ?? []).filter { $0 != walletId }
        userDefaults.set(shown, forKey: Self.key)
    }

    func markShown(for walletId: MetaAccountId) {
        var shown = userDefaults.stringArray(forKey: Self.key) ?? []
        guard !shown.contains(walletId) else { return }
        shown.append(walletId)
        userDefaults.set(shown, forKey: Self.key)
    }
}
