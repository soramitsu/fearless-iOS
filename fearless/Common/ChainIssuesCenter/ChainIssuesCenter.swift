import Foundation

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
}

final class ChainsIssuesCenter: ChainsIssuesCenterProtocol {
    private var issuesListeners: [WeakWrapper] = []
    private let networkIssuesCenter: NetworkIssuesCenterProtocol
    private let eventCenter: EventCenter
    private let missingAccountFetcher: MissingAccountFetcherProtocol

    private var wallet: MetaAccountModel
    private var networkIssuesChains: [ChainModel] = []
    private var missingAccountsChains: [ChainModel] = []

    init(
        wallet: MetaAccountModel,
        networkIssuesCenter: NetworkIssuesCenterProtocol,
        eventCenter: EventCenter,
        missingAccountHelper: MissingAccountFetcherProtocol
    ) {
        self.wallet = wallet
        self.networkIssuesCenter = networkIssuesCenter
        self.eventCenter = eventCenter
        missingAccountFetcher = missingAccountHelper

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
        issuesListeners = issuesListeners.filter { $0 !== listener }
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
}

extension ChainsIssuesCenter: NetworkIssuesCenterListener {
    func handleChainsWithIssues(_ chains: [ChainModel]) {
        networkIssuesChains = chains
        notify()
    }
}

extension ChainsIssuesCenter: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return
        }
        self.wallet = wallet

        missingAccountFetcher.fetchMissingAccounts(for: wallet) { [weak self] missingAccounts in
            self?.missingAccountsChains = missingAccounts
            self?.notify()
        }
    }
}
