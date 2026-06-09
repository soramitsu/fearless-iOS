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
    #if F_DEV
        static let filtersNetworkIssuesByPositiveBalances = false
    #else
        static let filtersNetworkIssuesByPositiveBalances = true
    #endif

    private var issuesListeners: [WeakWrapper] = []
    private let networkIssuesCenter: NetworkIssuesCenterProtocol
    private let eventCenter: EventCenterProtocol
    private let missingAccountFetcher: MissingAccountFetcherProtocol
    private let accountInfoFetcher: AccountInfoFetchingProtocol

    private var wallet: MetaAccountModel
    private var networkIssuesChains: [ChainModel] = []
    private var missingAccountsChains: [ChainModel] = []

    init(
        wallet: MetaAccountModel,
        networkIssuesCenter: NetworkIssuesCenterProtocol,
        eventCenter: EventCenterProtocol,
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
            self?.missingAccountsChains = missingAccounts
            self?.notify()
        }
    }

    func addIssuesListener(
        _ listener: ChainsIssuesCenterListener,
        getExisting: Bool
    ) {
        let weakListener = WeakWrapper(target: listener)
        issuesListeners.append(weakListener)

        guard getExisting else { return }
        (weakListener.target as? ChainsIssuesCenterListener)?.handleChainsIssues(fetchIssues())
    }

    func removeIssuesListener(_ listener: ChainsIssuesCenterListener) {
        issuesListeners = issuesListeners.filter { wrapper in
            guard let target = wrapper.target else {
                return false
            }

            return target !== listener
        }
    }

    func forceNotify() {
        networkIssuesCenter.forceNotify()
    }

    // MARK: - Private methods

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

    private func notify() {
        issuesListeners.forEach {
            ($0.target as? ChainsIssuesCenterListener)?.handleChainsIssues(fetchIssues())
        }
    }

    private func filterPositiveBalances(chains: [ChainModel]) {
        let chainAssets = chains.compactMap { $0.chainAssets }.reduce([], +)
        accountInfoFetcher.fetch(for: chainAssets, wallet: wallet) { [weak self] accountInfosByChainAssets in
            self?.networkIssuesChains = accountInfosByChainAssets
                .filter { $0.value?.nonZero() == true }
                .compactMap { $0.key.chain }
            self?.notify()
        }
    }
}

extension ChainsIssuesCenter: NetworkIssuesCenterListener {
    func handleChainsWithIssues(_ chains: [ChainModel]) {
        if Self.filtersNetworkIssuesByPositiveBalances {
            filterPositiveBalances(chains: chains)
        } else {
            networkIssuesChains = chains
            notify()
        }
    }
}

extension ChainsIssuesCenter: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account

        missingAccountFetcher.fetchMissingAccounts(for: wallet) { [weak self] missingAccounts in
            self?.missingAccountsChains = missingAccounts
            self?.notify()
        }
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        wallet = event.account

        missingAccountFetcher.fetchMissingAccounts(for: wallet) { [weak self] missingAccounts in
            guard self?.missingAccountsChains != missingAccounts else {
                return
            }
            self?.missingAccountsChains = missingAccounts
            self?.notify()
        }
    }
}
