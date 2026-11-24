import Foundation
import SoraKeystore
import SSFModels
import UIKit

extension Notification.Name {
    /// Wallets whose protected items vanished after their move (the device passcode was
    /// removed). `userInfo["walletIds"]` lists them; they must be restored from their backup.
    static let protectedWalletSecretsLost = Notification.Name("protectedWalletSecretsLost")
}

/// Installs the router before any wallet secret is read, finishes interrupted moves, and moves
/// wallets right after an authorized unlock (design doc 3.2–3.6).
final class ProtectedWalletSecretCoordinator {
    static let shared = ProtectedWalletSecretCoordinator()

    private let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.protected-keychain", qos: .userInitiated)
    private let lock = NSLock()
    private var journal: ProtectedWalletSecretJournaling?
    private var migrator: ProtectedWalletSecretMigrator?
    private var unlockObserver: NSObjectProtocol?
    /// Wallets whose move the user cancelled in this session: not offered again until relaunch.
    private var skippedThisSession = Set<MetaAccountId>()
    private var isMigrating = false

    private let isEnabled: () -> Bool
    private let allWallets: () async -> [MetaAccountModel]
    private let notificationCenter: NotificationCenter
    private let logger: LoggerProtocol?

    init(
        isEnabled: @escaping () -> Bool = { ProtectedKeychainPolicy.isEnabled },
        allWallets: @escaping () async -> [MetaAccountModel] = ServiceCoordinator.storedWallets,
        notificationCenter: NotificationCenter = .default,
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.isEnabled = isEnabled
        self.allWallets = allWallets
        self.notificationCenter = notificationCenter
        self.logger = logger
    }

    /// At launch. The router goes in when the flag is on or when anything was ever moved (a journal
    /// record or a protected item exists). With the flag off and nothing moved, nothing changes.
    /// If the keychain cannot answer yet (a launch before the first unlock after a restart), the
    /// check runs again when protected data becomes available and at every unlock; no wallet
    /// secret is readable before then anyway.
    func install(
        journal makeJournal: @escaping () -> ProtectedWalletSecretJournaling? = { try? KeychainProtectedWalletSecretJournal() },
        protected: ProtectedSecretBackend = ProtectedKeychain()
    ) {
        lock.lock()
        let installed = migrator != nil
        lock.unlock()
        guard !installed else {
            return
        }
        let journal = makeJournal()
        let protectedItems = (try? protected.allAccounts()).map { !$0.isEmpty }
        let moved = journal?.records.isEmpty == false || protectedItems == true
        guard isEnabled() || moved else {
            if journal == nil || protectedItems == nil {
                retryInstallLater(journal: makeJournal, protected: protected)
            }
            return
        }
        let resolvedJournal = journal ?? ReloadingProtectedWalletSecretJournal()
        let router = ProtectedWalletSecretRouter(protected: protected, journal: resolvedJournal)
        let migrator = ProtectedWalletSecretMigrator(
            protected: protected,
            journal: resolvedJournal,
            isEnabled: isEnabled,
            afterJournalSave: Self.deviceTestStop
        )
        lock.lock()
        self.journal = resolvedJournal
        self.migrator = migrator
        lock.unlock()
        Keychain.itemRouter = router
        WalletSecretAuthorization.shared.setAccepting(true)
        retryObservers.forEach(notificationCenter.removeObserver)
        retryObservers.removeAll()

        unlockObserver = notificationCenter.addObserver(
            forName: .walletAuthorizedUnlock,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Interrupted moves are finished whatever the flag says; new moves need it on.
            self?.recover()
            self?.migrateAfterUnlock()
        }
        recover()
    }

    private var retryObservers: [NSObjectProtocol] = []

    private func retryInstallLater(
        journal makeJournal: @escaping () -> ProtectedWalletSecretJournaling?,
        protected: ProtectedSecretBackend
    ) {
        guard retryObservers.isEmpty else {
            return
        }
        let retry: (Notification) -> Void = { [weak self] _ in
            self?.install(journal: makeJournal, protected: protected)
        }
        retryObservers = [
            UIApplication.protectedDataDidBecomeAvailableNotification,
            UIApplication.didBecomeActiveNotification,
            .walletAuthorizedUnlock
        ].map { notificationCenter.addObserver(forName: $0, object: nil, queue: .main, using: retry) }
    }

    private func recover() {
        lock.lock()
        let migrator = self.migrator
        lock.unlock()
        guard let migrator else {
            return
        }
        queue.async { [weak self] in
            self?.report(lost: migrator.recoverInterrupted())
        }
    }

    /// The wallet was removed and its secrets erased: its journal entry goes too. Protected items
    /// left by an erase that failed stay readable through the router's tag rule.
    func forget(walletId: MetaAccountId) {
        lock.lock()
        let journal = self.journal
        lock.unlock()
        try? journal?.remove(walletId: walletId)
        ProtectedKeychainRecoveryEvidence.shared.forget(walletId: walletId)
    }

    /// Moves every eligible wallet, one system sheet for all of them (none after a Face ID unlock).
    func migrateAfterUnlock() {
        guard isEnabled() else {
            return
        }
        lock.lock()
        guard let migrator, !isMigrating else {
            lock.unlock()
            return
        }
        isMigrating = true
        let skipped = skippedThisSession
        lock.unlock()

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let wallets = await self.allWallets()
            self.queue.async {
                var cancelled = false
                for wallet in wallets where !skipped.contains(wallet.metaId) && !cancelled {
                    let outcome = migrator.migrate(wallet, context: WalletSecretAuthorization.shared.currentContext())
                    switch outcome {
                    case .committed:
                        self.logger?.info("Protected keychain: a wallet moved")
                    case .deferred(.canceled), .deferred(.authenticationFailed):
                        // The user said no: ask again at the next launch, not at every unlock.
                        cancelled = true
                    case .deferred, .alreadyCommitted:
                        break
                    }
                }
                self.lock.lock()
                if cancelled {
                    self.skippedThisSession.formUnion(wallets.map(\.metaId))
                }
                self.isMigrating = false
                self.lock.unlock()
                self.report(lost: migrator.recoverInterrupted())
            }
        }
    }

    /// Debug builds only: `FEARLESS_PROTECTED_KEYCHAIN_STOP_AT=<state>` ends the process right after
    /// that journal state is saved, as a crash or a force-quit would (device test plan, D5).
    private static func deviceTestStop(_ state: ProtectedWalletSecretRecord.State) {
        #if DEBUG
            if ProcessInfo.processInfo.environment["FEARLESS_PROTECTED_KEYCHAIN_STOP_AT"] == state.rawValue {
                exit(0)
            }
        #endif
    }

    private func report(lost: [MetaAccountId]) {
        guard !lost.isEmpty else {
            return
        }
        logger?.error("Protected keychain: \(lost.count) wallet(s) lost their protected items")
        DispatchQueue.main.async { [notificationCenter] in
            notificationCenter.post(name: .protectedWalletSecretsLost, object: nil, userInfo: ["walletIds": lost])
        }
    }
}

/// The keychain journal when it could not be read at launch (before the first unlock after a
/// restart): it tries again on each use until it loads.
final class ReloadingProtectedWalletSecretJournal: ProtectedWalletSecretJournaling {
    private let lock = NSLock()
    private var loaded: KeychainProtectedWalletSecretJournal?

    private func journal() -> KeychainProtectedWalletSecretJournal? {
        lock.lock()
        defer { lock.unlock() }
        if loaded == nil {
            loaded = try? KeychainProtectedWalletSecretJournal()
        }
        return loaded
    }

    var records: [ProtectedWalletSecretRecord] {
        journal()?.records ?? []
    }

    func record(for walletId: MetaAccountId) -> ProtectedWalletSecretRecord? {
        journal()?.record(for: walletId)
    }

    func save(_ record: ProtectedWalletSecretRecord) throws {
        guard let journal = journal() else {
            throw ProtectedKeychainError.interactionNotAllowed
        }
        try journal.save(record)
    }

    func remove(walletId: MetaAccountId) throws {
        guard let journal = journal() else {
            throw ProtectedKeychainError.interactionNotAllowed
        }
        try journal.remove(walletId: walletId)
    }
}
