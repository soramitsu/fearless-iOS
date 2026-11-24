import Foundation
import SoraKeystore
import SSFModels

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

    /// At launch. The router goes in when the flag is on, when any wallet has protected items
    /// or a journal, or when either cannot be read yet (before the first unlock after a restart):
    /// with nothing moved it routes every read exactly as before.
    func install(
        journal makeJournal: () -> ProtectedWalletSecretJournaling? = { try? KeychainProtectedWalletSecretJournal() },
        protected: ProtectedSecretBackend = ProtectedKeychain()
    ) {
        let journal = makeJournal()
        let protectedItems = (try? protected.allAccounts()).map { !$0.isEmpty }
        let needsRouter = isEnabled()
            || journal == nil
            || journal?.records.isEmpty == false
            || protectedItems != false
        guard needsRouter else {
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

        unlockObserver = notificationCenter.addObserver(
            forName: .walletAuthorizedUnlock,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.migrateAfterUnlock()
        }

        queue.async { [weak self] in
            let lost = migrator.recoverInterrupted()
            self?.report(lost: lost)
        }
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
