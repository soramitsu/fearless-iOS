import Foundation
import SSFModels

enum ChainIssue {
    case network(chains: [ChainModel])
    case missingAccount(chains: [ChainModel])
}

protocol ChainsIssuesCenterListener: AnyObject {
    func handleChainsIssues(_ issues: [ChainIssue])
}

protocol ChainsIssuesCenterProtocol {
    func addIssuesListener(
        _ listener: ChainsIssuesCenterListener,
        getExisting: Bool
    )
    func removeIssuesListener(_ listener: ChainsIssuesCenterListener)
    func forceNotify()
}

final class ChainsIssuesCenter: ChainsIssuesCenterProtocol {
    // Screens add listeners while the event queue and fetch callbacks publish
    // issues, so the state below is only touched under this lock. Listeners are
    // called after it is released.
    private let lock = NSLock()
    private var issuesListeners: [WeakWrapper] = []
    private let networkIssuesCenter: NetworkIssuesCenterProtocol
    private let eventCenter: EventCenter
    private let missingAccountFetcher: MissingAccountFetcherProtocol
    private let accountInfoFetcher: AccountInfoFetchingProtocol

    private var wallet: MetaAccountModel
    private var networkIssuesChains: [ChainModel] = []
    private var missingAccountsChains: [ChainModel] = []

    init(
        wallet: MetaAccountModel,
        networkIssuesCenter: NetworkIssuesCenterProtocol,
        eventCenter: EventCenter,
        missingAccountHelper: MissingAccountFetcherProtocol,
        accountInfoFetcher: AccountInfoFetchingProtocol
    ) {
        self.wallet = wallet
        self.networkIssuesCenter = networkIssuesCenter
        self.eventCenter = eventCenter
        missingAccountFetcher = missingAccountHelper
        self.accountInfoFetcher = accountInfoFetcher

        self.networkIssuesCenter.addIssuesListener(self, getExisting: true)
        self.eventCenter.add(observer: self, dispatchIn: nil)

        missingAccountFetcher.fetchMissingAccounts(for: wallet) { [weak self] missingAccounts in
            self?.setMissingAccountsChains(missingAccounts)
        }
    }

    func addIssuesListener(
        _ listener: ChainsIssuesCenterListener,
        getExisting: Bool
    ) {
        lock.lock()
        issuesListeners.append(WeakWrapper(target: listener))
        let issues = fetchIssues()
        lock.unlock()

        guard getExisting else { return }
        listener.handleChainsIssues(issues)
    }

    func removeIssuesListener(_ listener: ChainsIssuesCenterListener) {
        lock.lock()
        issuesListeners = issuesListeners.filter { $0.target !== listener }
        lock.unlock()
    }

    func forceNotify() {
        networkIssuesCenter.forceNotify()
    }

    // MARK: - Private methods

    /// Call with `lock` held.
    private func fetchIssues() -> [ChainIssue] {
        var issues: [ChainIssue] = []
        if networkIssuesChains.isNotEmpty {
            issues.append(.network(chains: networkIssuesChains))
        }

        if missingAccountsChains.isNotEmpty {
            issues.append(.missingAccount(chains: missingAccountsChains))
        }
        return issues
    }

    /// Stores a change under the lock, then tells every listener, unless the
    /// change reports that nothing is new.
    private func publish(_ change: () -> Bool) {
        lock.lock()
        let changed = change()
        let issues = fetchIssues()
        let listeners = issuesListeners
        lock.unlock()

        guard changed else { return }
        listeners.forEach {
            ($0.target as? ChainsIssuesCenterListener)?.handleChainsIssues(issues)
        }
    }

    private func setNetworkIssuesChains(_ chains: [ChainModel]) {
        publish {
            networkIssuesChains = chains
            return true
        }
    }

    private func setMissingAccountsChains(_ chains: [ChainModel], onlyIfChanged: Bool = false) {
        publish {
            if onlyIfChanged, missingAccountsChains == chains {
                return false
            }
            missingAccountsChains = chains
            return true
        }
    }

    private func currentWallet() -> MetaAccountModel {
        lock.lock()
        defer { lock.unlock() }
        return wallet
    }

    private func filterPositiveBalances(chains: [ChainModel]) {
        let chainAssets = chains.compactMap { $0.chainAssets }.reduce([], +)
        accountInfoFetcher.fetch(for: chainAssets, wallet: currentWallet()) { [weak self] accountInfosByChainAssets in
            self?.setNetworkIssuesChains(
                accountInfosByChainAssets.filter { $0.value?.nonZero() == true }.compactMap { $0.key.chain }
            )
        }
    }
}

extension ChainsIssuesCenter: NetworkIssuesCenterListener {
    func handleChainsWithIssues(_ chains: [ChainModel]) {
        #if F_DEV
            setNetworkIssuesChains(chains)
        #else
            filterPositiveBalances(chains: chains)
        #endif
    }
}

extension ChainsIssuesCenter: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        lock.lock()
        wallet = event.account
        lock.unlock()

        missingAccountFetcher.fetchMissingAccounts(for: event.account) { [weak self] missingAccounts in
            self?.setMissingAccountsChains(missingAccounts)
        }
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        lock.lock()
        let isCurrentWallet = wallet.metaId == event.account.metaId
        if isCurrentWallet {
            wallet = event.account
        }
        lock.unlock()

        guard isCurrentWallet else { return }

        missingAccountFetcher.fetchMissingAccounts(for: event.account) { [weak self] missingAccounts in
            self?.setMissingAccountsChains(missingAccounts, onlyIfChanged: true)
        }
    }
}
