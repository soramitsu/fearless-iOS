import Foundation
import SSFModels

enum PortfolioLens: String, CaseIterable {
    case token
    case network
}

/// A request belongs to a particular wallet/presentation generation. Delivery
/// is checked on the main queue, after any queued wallet selection changes.
final class PortfolioCallbackScope {
    private let lock = NSLock()
    private var generation = UUID()

    func snapshot() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    @discardableResult
    func invalidate() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        generation = UUID()
        return generation
    }

    func isCurrent(_ request: UUID) -> Bool {
        snapshot() == request
    }

    func deliver(_ request: UUID, _ action: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard self?.isCurrent(request) == true else { return }
            action()
        }
    }
}

/// Keeps a subscription's original wallet and generation even if its last
/// callback was already queued when the adapter was reset.
final class PortfolioAccountInfoListener: AccountInfoSubscriptionAdapterHandler {
    private let wallet: MetaAccountModel
    private let scope: PortfolioCallbackScope
    private let request: UUID
    private let receive: (Result<AccountInfo?, Error>, ChainAsset) -> Void

    init(wallet: MetaAccountModel, scope: PortfolioCallbackScope, receive: @escaping (Result<AccountInfo?, Error>, ChainAsset) -> Void) {
        self.wallet = wallet
        self.scope = scope
        request = scope.snapshot()
        self.receive = receive
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        guard wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId == accountId else { return }
        scope.deliver(request) { [receive] in receive(result, chainAsset) }
    }
}

/// Presentation preferences only. Invalid or oversized state falls back without touching wallet data.
final class PortfolioCollapseStore {
    private let defaults: UserDefaults
    private let limit = 256

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
    }

    func lens(walletId: String) -> PortfolioLens {
        defaults.string(forKey: "portfolio.lens:\(walletId)").flatMap(PortfolioLens.init(rawValue:)) ?? .token
    }

    func setLens(_ lens: PortfolioLens, walletId: String) {
        defaults.set(lens.rawValue, forKey: "portfolio.lens:\(walletId)")
    }

    func identifiers(walletId: String, kind: String) -> Set<String> {
        guard let values = defaults.array(forKey: key(walletId, kind)) as? [String],
              values.count <= limit,
              values.allSatisfy({ !$0.isEmpty && $0.count <= 256 }) else { return [] }
        return Set(values)
    }

    func setIdentifiers(_ ids: Set<String>, walletId: String, kind: String) {
        guard ids.count <= limit, ids.allSatisfy({ !$0.isEmpty && $0.count <= 256 }) else { return }
        defaults.set(ids.sorted(), forKey: key(walletId, kind))
    }

    private func key(_ walletId: String, _ kind: String) -> String {
        "portfolio.collapsed:\(walletId):\(kind)"
    }
}
