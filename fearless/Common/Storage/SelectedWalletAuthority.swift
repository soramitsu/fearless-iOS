import Foundation

/// One settings instance owns one revision history. An A → B → A transition never revives
/// an old review. Only name and backup-marker updates are explicitly identity-preserving;
/// all account/key fields and other metadata changes conservatively revoke the revision.
final class SelectedWalletAuthority {
    struct Lease {
        fileprivate let authority: SelectedWalletAuthority
        fileprivate let revision: UUID
        fileprivate let identity: MetaAccountModel

        var isCurrent: Bool {
            authority.isCurrent(self)
        }

        func requireCurrent() throws {
            guard isCurrent else { throw CancellationError() }
        }
    }

    private let lock = NSLock()
    private var revision = UUID()
    private var identity: MetaAccountModel?

    /// Called only by the owning settings object's value-publication hook. No client code
    /// runs while either lock is held. Mutation work is admitted by a check, then executes
    /// outside these locks; selection cannot undo an operation already admitted to output.
    private func normalized(_ wallet: MetaAccountModel) -> MetaAccountModel {
        wallet.replacingName("").replacingIsBackuped(false)
    }

    func publish(_ wallet: MetaAccountModel?) {
        let next = wallet.map(normalized)
        lock.lock()
        defer { lock.unlock() }
        guard identity != next else { return }
        identity = next
        revision = UUID()
    }

    func capture(for wallet: MetaAccountModel) -> Lease {
        lock.lock()
        defer { lock.unlock() }
        return Lease(authority: self, revision: revision, identity: normalized(wallet))
    }

    private func isCurrent(_ lease: Lease) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return revision == lease.revision && identity == lease.identity
    }
}

/// Scoped to confirmation's actual async pipeline, including its injected service in tests.
/// Read-only settlement after admitted output does not require a current selection; key,
/// signing and new output boundaries do. Independent service consumers remain unscoped.
enum SolanaSendAuthorization {
    @TaskLocal static var selection: SelectedWalletAuthority.Lease?

    static func requireCurrent() throws {
        try Task.checkCancellation()
        try selection?.requireCurrent()
    }
}
