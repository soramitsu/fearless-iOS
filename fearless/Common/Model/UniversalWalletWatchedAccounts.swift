import Foundation
import SSFModels

/// The networks of a password wallet where the words open two accounts that may both have been
/// shown: one the wallet left on Switch, or either one after an import or enrolment, which cannot
/// tell which one another release or client showed. Whichever account such a network does not
/// show is watched for the wallet's lifetime, because a deposit can land there at any time.
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

/// Funds that reached the watched account of a network while the wallet shows the other one,
/// which holds funds too or could not be checked.
struct UniversalWalletOldAddressArrival: Equatable {
    let slot: UniversalWalletSlot
    /// The address the funds reached: an old one the words alone open or, when
    /// `atProtectedAddress`, the password-protected one.
    let oldAddress: String
    let balance: String?
    var atProtectedAddress = false
    /// The wallet whose check found the funds; acknowledging records them for that wallet.
    var walletId: MetaAccountId?

    var notificationKey: String {
        "\(slot.rawValue)|\(atProtectedAddress ? "protected|" : "")\(oldAddress)|\(balance ?? "funded")"
    }

    var networkName: String {
        slot.networkName
    }
}

/// Checks the account each watched network of a password wallet does not show. Funds there move
/// the network to that account when the one it shows is confirmed empty; otherwise the shown
/// account stays and the arrival is reported. Nothing is saved here.
final class UniversalWalletWatchedAccountsChecker {
    struct Result: Equatable {
        let wallet: MetaAccountModel
        /// Networks moved back to the old account the words alone open.
        let movedBack: [UniversalWalletSlot]
        /// Networks moved to the account the password protects.
        var movedToProtected: [UniversalWalletSlot] = []
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
        let shown = shownAccounts(in: wallet, root: root, wordsOnly: wordsOnly)
        guard !shown.protected.isEmpty || !shown.old.isEmpty else { return unchanged }

        // The account each network does not show: the old one beside a protected one, and back.
        let probe = fundsProbe()
        let leftOld = await Self.funds(of: wordsOnly, slots: shown.protected, probe: probe)
        let leftProtected = await Self.funds(of: root, slots: shown.old, probe: probe)
        let paidOld = shown.protected.filter { leftOld[$0]?.state == .funded }
        let paidProtected = shown.old.filter { leftProtected[$0]?.state == .funded }
        guard !paidOld.isEmpty || !paidProtected.isEmpty else { return unchanged }
        // A network leaves the account it shows only when that account is confirmed empty.
        let shownProtected = await Self.funds(of: root, slots: paidOld, probe: probe)
        let shownOld = await Self.funds(of: wordsOnly, slots: paidProtected, probe: probe)

        var accounts = wallet.chainAccounts
        var movedBack: [UniversalWalletSlot] = []
        var movedToProtected: [UniversalWalletSlot] = []
        var arrivals: [UniversalWalletOldAddressArrival] = []
        for slot in UniversalWalletSlot.allCases where paidOld.contains(slot) || paidProtected.contains(slot) {
            let toProtected = paidProtected.contains(slot)
            guard let stored = slot.storedAccount(in: wallet),
                  let key = try? slot.publicKey(for: toProtected ? root : wordsOnly),
                  let address = UniversalWalletChainAccountSupport.address(for: slot.chainId, publicKey: key)
            else { continue }
            if (toProtected ? shownOld[slot] : shownProtected[slot])?.state == .empty {
                accounts.remove(stored)
                accounts.insert(ChainAccountModel(
                    chainId: stored.chainId,
                    accountId: key,
                    publicKey: key,
                    cryptoType: stored.cryptoType,
                    ethereumBased: false
                ))
                if toProtected {
                    movedToProtected.append(slot)
                } else {
                    movedBack.append(slot)
                }
            } else {
                // Funded or unknown: never hide the funds of the account the network shows.
                arrivals.append(UniversalWalletOldAddressArrival(
                    slot: slot,
                    oldAddress: address,
                    balance: (toProtected ? leftProtected[slot] : leftOld[slot])?.balance,
                    atProtectedAddress: toProtected,
                    walletId: wallet.metaId
                ))
            }
        }

        let updated = accounts == wallet.chainAccounts ? wallet : wallet.replacingChainAccounts(accounts)
        return Result(wallet: updated, movedBack: movedBack, movedToProtected: movedToProtected, arrivals: arrivals)
    }

    /// The watched networks that show the account the password protects, and those that show
    /// the old one the words alone open.
    private func shownAccounts(
        in wallet: MetaAccountModel,
        root: UniversalWalletSecret,
        wordsOnly: UniversalWalletSecret
    ) -> (protected: Set<UniversalWalletSlot>, old: Set<UniversalWalletSlot>) {
        var protected: Set<UniversalWalletSlot> = []
        var old: Set<UniversalWalletSlot> = []
        for slot in watchedAccounts.watchedSlots(in: wallet.metaId) {
            guard let account = slot.storedAccount(in: wallet),
                  let protectedKey = try? slot.publicKey(for: root),
                  let oldKey = try? slot.publicKey(for: wordsOnly),
                  protectedKey != oldKey else {
                continue
            }
            if account.publicKey == protectedKey {
                protected.insert(slot)
            } else if account.publicKey == oldKey {
                old.insert(slot)
            }
        }
        return (protected, old)
    }

    private static func funds(
        of secret: UniversalWalletSecret,
        slots: Set<UniversalWalletSlot>,
        probe: UniversalWalletFundsProbing
    ) async -> [UniversalWalletSlot: UniversalWalletFundsReading] {
        guard !slots.isEmpty else { return [:] }
        return await probe.funds(of: secret, slots: slots)
    }
}

extension Notification.Name {
    /// The portfolio was refreshed: watched old addresses are checked again.
    static let universalWalletPortfolioRefreshed = Notification.Name("universalWalletPortfolioRefreshed")
}
