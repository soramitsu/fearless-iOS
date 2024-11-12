import UIKit
import SSFModels
import RobinHood

protocol ConnectedAccountsInteractorOutput: AnyObject {
    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>)
}

final class ConnectedAccountsInteractor {
    // MARK: - Private properties
    private weak var output: ConnectedAccountsInteractorOutput?

    private let wallet: MetaAccountModel
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let chainRepository: AsyncAnyRepository<ChainModel>

    init(
        wallet: MetaAccountModel,
        chainRepository: AsyncAnyRepository<ChainModel>,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    ) {
        self.wallet = wallet
        self.chainRepository = chainRepository
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
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
