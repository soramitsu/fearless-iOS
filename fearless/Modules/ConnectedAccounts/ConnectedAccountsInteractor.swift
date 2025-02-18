import UIKit
import SSFModels
import RobinHood

protocol ConnectedAccountsInteractorOutput: AnyObject {
    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>)
    func processSelectedAccountChanged(wallet: MetaAccountModel)
}

final class ConnectedAccountsInteractor {
    // MARK: - Private properties
    private weak var output: ConnectedAccountsInteractorOutput?

    private var wallet: MetaAccountModel
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let chainRepository: AsyncAnyRepository<ChainModel>
    private let eventCenter: EventCenterProtocol

    init(
        wallet: MetaAccountModel,
        chainRepository: AsyncAnyRepository<ChainModel>,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.wallet = wallet
        self.chainRepository = chainRepository
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.eventCenter = eventCenter
        eventCenter.add(observer: self, dispatchIn: .global())
    }

    // MARK: - Private methods

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletBalance(
            wallet: wallet,
            listener: self
        )
    }
}

// MARK: - ConnectedAccountsInteractorInput
extension ConnectedAccountsInteractor: ConnectedAccountsInteractorInput {
    var chains: [ChainModel] {
        get async throws {
            try await chainRepository.fetchAll()
        }
    }

    func setup(with output: ConnectedAccountsInteractorOutput) {
        self.output = output
        fetchBalances()
    }
}

// MARK: - WalletBalanceSubscriptionListener

extension ConnectedAccountsInteractor: WalletBalanceSubscriptionListener {
    var type: WalletBalanceListenerType {
        .wallet(wallet: wallet)
    }

    func handle(result: WalletBalancesResult) {
        output?.didReceiveWalletBalances(result)
    }
}

// MARK: - EventVisitorProtocol

extension ConnectedAccountsInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account
        output?.processSelectedAccountChanged(wallet: wallet)
    }
}
