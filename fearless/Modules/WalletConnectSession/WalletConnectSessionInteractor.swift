import UIKit
import RobinHood
import SSFModels

protocol WalletConnectSessionInteractorOutput: AnyObject {
    func didReceiveBalance(result: WalletBalancesResult)
    func didReceive(chainsResult: Result<[ChainModel], Error>)
    func didReceive(walletsResult: Result<[MetaAccountModel], Error>)
}

final class WalletConnectSessionInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectSessionInteractorOutput?

    private let walletConnect: WalletConnectService
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    init(
        walletConnect: WalletConnectService,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.walletConnect = walletConnect
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.walletRepository = walletRepository
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
    }

    // MARK: - Private methods

    private func fetchBalances() {
        walletBalanceSubscriptionAdapter.subscribeWalletsBalances(listener: self)
    }

    private func fetchChainModels() {
        Task { [weak self] in
            guard let self else { return }
            let result: Result<[ChainModel], Error>
            do {
                let chains = try await chainRepository.fetchAllAsync()
                result = .success(chains)
            } catch {
                result = .failure(error)
            }
            await MainActor.run { [weak self] in
                self?.output?.didReceive(chainsResult: result)
            }
        }
    }

    private func fetchWallets() {
        Task { [weak self] in
            guard let self else { return }
            let result: Result<[MetaAccountModel], Error>
            do {
                let wallets = try await walletRepository.fetchAllAsync()
                result = .success(wallets)
            } catch {
                result = .failure(error)
            }
            await MainActor.run { [weak self] in
                self?.output?.didReceive(walletsResult: result)
            }
        }
    }
}

// MARK: - WalletConnectSessionInteractorInput

extension WalletConnectSessionInteractor: WalletConnectSessionInteractorInput {
    func submit(signDecision: WalletConnectSignDecision) async throws {
        try await walletConnect.submit(signDecision: signDecision)
    }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        try await walletConnect.submit(proposalDecision: proposalDecision)
    }

    func setup(with output: WalletConnectSessionInteractorOutput) {
        self.output = output
        fetchBalances()
        fetchChainModels()
        fetchWallets()
    }
}

// MARK: - WalletBalanceSubscriptionHandler

extension WalletConnectSessionInteractor: WalletBalanceSubscriptionListener {
    var type: WalletBalanceListenerType {
        .wallets
    }

    func handle(result: WalletBalancesResult) {
        output?.didReceiveBalance(result: result)
    }
}
