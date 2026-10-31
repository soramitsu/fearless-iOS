import Foundation
import SSFModels

/// The accounts the words alone open that a password wallet left for the ones its password
/// protects (Switch, or an import or enrolment that found them empty). A deposit can land after
/// the check that let the wallet leave them, so they stay watched for the wallet's lifetime.
final class UniversalWalletWatchedAccountsStore {
    static let watchedKey = "universalWalletWatchedNoPasswordSlots"
    static let notifiedKey = "universalWalletNotifiedOldAddressFunds"
    private static let lock = NSLock()

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func watch(_ slots: Set<UniversalWalletSlot>, in walletId: MetaAccountId) {
        guard !slots.isEmpty else { return }
        update(Self.watchedKey) { watched in
            let current = Set(watched[walletId] ?? [])
            watched[walletId] = current.union(slots.map(\.rawValue)).sorted()
        }
    }

    func watchedSlots(in walletId: MetaAccountId) -> Set<UniversalWalletSlot> {
        Set(read(Self.watchedKey)[walletId, default: []].compactMap(UniversalWalletSlot.init(rawValue:)))
    }

    /// The only way an entry goes: the wallet itself is removed.
    func forget(walletId: MetaAccountId) {
        update(Self.watchedKey) { $0[walletId] = nil }
        update(Self.notifiedKey) { $0[walletId] = nil }
    }

    /// Arrivals not shown yet with this balance; new funds at a watched address show again.
    func unnotified(
        _ arrivals: [UniversalWalletOldAddressArrival],
        in walletId: MetaAccountId
    ) -> [UniversalWalletOldAddressArrival] {
        let shown = Set(read(Self.notifiedKey)[walletId, default: []])
        return arrivals.filter { !shown.contains($0.notificationKey) }
    }

    func markNotified(_ arrivals: [UniversalWalletOldAddressArrival], in walletId: MetaAccountId) {
        update(Self.notifiedKey) { notified in
            let shownSlots = Set(arrivals.map { "\($0.slot.rawValue)|" })
            let kept = (notified[walletId] ?? []).filter { key in !shownSlots.contains { key.hasPrefix($0) } }
            notified[walletId] = kept + arrivals.map(\.notificationKey)
        }
    }

    private func read(_ key: String) -> [String: [String]] {
        (userDefaults.dictionary(forKey: key) as? [String: [String]]) ?? [:]
    }

    private func update(_ key: String, _ change: (inout [String: [String]]) -> Void) {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        var value = read(key)
        change(&value)
        userDefaults.set(value, forKey: key)
    }
}

/// Funds that reached a watched old address while the wallet keeps its password-protected one.
struct UniversalWalletOldAddressArrival: Equatable {
    let slot: UniversalWalletSlot
    let oldAddress: String
    let balance: String?

    var notificationKey: String {
        "\(slot.rawValue)|\(balance ?? "funded")"
    }

    var networkName: String {
        slot.networkName
    }
}

/// Checks the watched old addresses of a password wallet. Funds there move the network back
/// to the old address when its password-protected account is confirmed empty; otherwise the
/// password-protected account stays and the arrival is reported. Nothing is saved here.
final class UniversalWalletWatchedAccountsChecker {
    struct Result: Equatable {
        let wallet: MetaAccountModel
        let movedBack: [UniversalWalletSlot]
        let arrivals: [UniversalWalletOldAddressArrival]
    }

    private let mnemonicProvider: UniversalWalletRootMnemonicProviding
    private let watchedAccounts: UniversalWalletWatchedAccountsStore
    private let fundsProbe: () -> UniversalWalletFundsProbing

    init(
        mnemonicProvider: UniversalWalletRootMnemonicProviding = KeychainUniversalWalletMnemonicProvider(),
        watchedAccounts: UniversalWalletWatchedAccountsStore = UniversalWalletWatchedAccountsStore(),
        fundsProbe: @escaping () -> UniversalWalletFundsProbing = { UniversalWalletRemoteFundsProbe.makeDefault() }
    ) {
        self.mnemonicProvider = mnemonicProvider
        self.watchedAccounts = watchedAccounts
        self.fundsProbe = fundsProbe
    }

    func check(_ wallet: MetaAccountModel) async -> Result {
        let unchanged = Result(wallet: wallet, movedBack: [], arrivals: [])
        guard let root = try? mnemonicProvider.rootSecret(for: wallet), !root.passphrase.isEmpty else {
            return unchanged
        }
        let wordsOnly = UniversalWalletSecret(mnemonic: root.mnemonic, passphrase: "")
        // Only networks that hold the password-protected account now; one already back on its
        // old address is listed by the notice.
        let protectedSlots = watchedAccounts.watchedSlots(in: wallet.metaId).filter { slot in
            guard let account = slot.storedAccount(in: wallet),
                  let protectedKey = try? slot.publicKey(for: root),
                  let oldKey = try? slot.publicKey(for: wordsOnly) else {
                return false
            }
            return account.publicKey == protectedKey && protectedKey != oldKey
        }
        guard !protectedSlots.isEmpty else { return unchanged }

        let probe = fundsProbe()
        let old = await probe.funds(of: wordsOnly, slots: protectedSlots)
        let funded = UniversalWalletSlot.allCases.filter { protectedSlots.contains($0) && old[$0]?.state == .funded }
        guard !funded.isEmpty else { return unchanged }
        let current = await probe.funds(of: root, slots: Set(funded))

        var accounts = wallet.chainAccounts
        var movedBack: [UniversalWalletSlot] = []
        var arrivals: [UniversalWalletOldAddressArrival] = []
        for slot in funded {
            guard let stored = slot.storedAccount(in: wallet),
                  let oldKey = try? slot.publicKey(for: wordsOnly),
                  let oldAddress = UniversalWalletChainAccountSupport.address(for: slot.chainId, publicKey: oldKey)
            else { continue }
            if current[slot]?.state == .empty {
                accounts.remove(stored)
                accounts.insert(ChainAccountModel(
                    chainId: stored.chainId,
                    accountId: oldKey,
                    publicKey: oldKey,
                    cryptoType: stored.cryptoType,
                    ethereumBased: false
                ))
                movedBack.append(slot)
            } else {
                // Funded or unknown: never hide the password-protected account's funds.
                arrivals.append(UniversalWalletOldAddressArrival(
                    slot: slot, oldAddress: oldAddress, balance: old[slot]?.balance
                ))
            }
        }

        let updated = accounts == wallet.chainAccounts ? wallet : wallet.replacingChainAccounts(accounts)
        return Result(wallet: updated, movedBack: movedBack, arrivals: arrivals)
    }
}

extension Notification.Name {
    /// The portfolio was refreshed: watched old addresses are checked again.
    static let universalWalletPortfolioRefreshed = Notification.Name("universalWalletPortfolioRefreshed")
}
