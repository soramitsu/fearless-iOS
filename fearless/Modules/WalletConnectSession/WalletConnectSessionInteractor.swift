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
        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            do {
                let chainModels = try operation.extractNoCancellableResultData()
                self?.output?.didReceive(chainsResult: .success(chainModels))
            } catch {
                self?.output?.didReceive(chainsResult: .failure(error))
            }
        }

        operationQueue.addOperation(operation)
    }

    private func fetchWallets() {
        let operation = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                return
            }
            self?.output?.didReceive(walletsResult: result)
        }

        operationQueue.addOperation(operation)
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
