import Foundation
import SSFModels
import UIKit

/// The moments the user has just proved who they are (the app PIN, the app's biometric check or
/// a new PIN). Background work that needs wallet secrets runs only then; balance refresh,
/// foreground events and timers never read a secret.
final class WalletAuthorizedUnlock {
    static let shared = WalletAuthorizedUnlock()
    /// Work started by an unlock finishes well within this; later events find the window closed.
    static let windowDuration: TimeInterval = 60

    private let lock = NSLock()
    private var lastUnlock: Date?
    private let now: () -> Date
    private let notificationCenter: NotificationCenter
    private var backgroundObserver: NSObjectProtocol?

    init(
        now: @escaping () -> Date = Date.init,
        notificationCenter: NotificationCenter = .default
    ) {
        self.now = now
        self.notificationCenter = notificationCenter
        backgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.close()
        }
    }

    deinit {
        backgroundObserver.map(notificationCenter.removeObserver)
    }

    /// Called on the main queue after a correct PIN, an accepted biometric check or a saved PIN.
    func recordUnlock() {
        lock.lock()
        lastUnlock = now()
        lock.unlock()
        notificationCenter.post(name: .walletAuthorizedUnlock, object: self)
    }

    /// Ends the window at once: the app locked or went to the background.
    func close() {
        lock.lock()
        lastUnlock = nil
        lock.unlock()
    }

    var isWindowOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let lastUnlock else {
            return false
        }
        let elapsed = now().timeIntervalSince(lastUnlock)
        return elapsed >= 0 && elapsed <= Self.windowDuration
    }
}

extension Notification.Name {
    /// The user unlocked the app with the PIN or a trusted biometric check.
    static let walletAuthorizedUnlock = Notification.Name("walletAuthorizedUnlock")
    /// A wallet's Bitcoin descriptors were made (`userInfo["walletId"]`): its balances can be read in full.
    static let bitcoinAccountDescriptorsSaved = Notification.Name("bitcoinAccountDescriptorsSaved")
}

/// Makes the public Bitcoin descriptors that balance refresh reads, from the wallet's secret,
/// only for accounts that have none yet. Callers run it at an authorized moment.
final class BitcoinAccountDescriptorBackfill {
    private let secretProvider: UniversalWalletSlotSecretProviding
    private let store: BitcoinAccountDescriptorStore
    private let logger: LoggerProtocol?

    init(
        secretProvider: UniversalWalletSlotSecretProviding = KeychainUniversalWalletMnemonicProvider(),
        store: BitcoinAccountDescriptorStore = .shared,
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.secretProvider = secretProvider
        self.store = store
        self.logger = logger
    }

    /// The Bitcoin slots of `wallet` with a stored account, no descriptor, and no earlier finding
    /// that no secret derives it. Reads no secret.
    func missingSlots(in wallet: MetaAccountModel) -> [UniversalWalletSlot] {
        [UniversalWalletSlot.bitcoinMainnet, .bitcoinTestnet].filter { slot in
            guard let network = slot.bitcoinNetwork,
                  let account = slot.storedAccount(in: wallet) else {
                return false
            }
            return !store.hasDescriptor(walletId: wallet.metaId, network: network, accountPublicKey: account.publicKey)
                && !store.isUnavailable(walletId: wallet.metaId, network: network, accountPublicKey: account.publicKey)
        }
    }

    /// Reads the wallet's secret once per missing account. Returns the number of descriptors saved.
    @discardableResult
    func backfill(_ wallet: MetaAccountModel) -> Int {
        var saved = 0
        for slot in missingSlots(in: wallet) {
            do {
                guard let secret = try secretProvider.secret(for: wallet, slot: slot) else {
                    // Nothing stored derives this account: refresh reads its address alone.
                    if let network = slot.bitcoinNetwork, let account = slot.storedAccount(in: wallet) {
                        store.markUnavailable(
                            walletId: wallet.metaId,
                            network: network,
                            accountPublicKey: account.publicKey
                        )
                    }
                    continue
                }
                if try record(secret, for: wallet, slot: slot) {
                    saved += 1
                }
            } catch {
                logger?.warning("Bitcoin descriptor for \(slot.rawValue) not made: \(error.localizedDescription)")
            }
        }
        return saved
    }

    /// Saves the descriptor of `secret` when it derives the account `wallet` stores for `slot`.
    /// For callers that already hold the secret, such as a confirmed transfer.
    @discardableResult
    func record(_ secret: UniversalWalletSecret, for wallet: MetaAccountModel, slot: UniversalWalletSlot) throws -> Bool {
        guard let network = slot.bitcoinNetwork,
              let account = slot.storedAccount(in: wallet) else {
            return false
        }
        let descriptor = try BitcoinKeyDerivation.deriveAccountDescriptor(
            mnemonic: secret.mnemonic,
            passphrase: secret.passphrase,
            network: network
        )
        guard try descriptor.firstReceivePublicKey() == account.publicKey else {
            return false
        }
        try store.save(descriptor, walletId: wallet.metaId)
        return true
    }
}

/// The secret that derives the account a wallet stores for a universal slot.
protocol UniversalWalletSlotSecretProviding {
    func secret(for wallet: MetaAccountModel, slot: UniversalWalletSlot) throws -> UniversalWalletSecret?
}

extension KeychainUniversalWalletMnemonicProvider: UniversalWalletSlotSecretProviding {}
