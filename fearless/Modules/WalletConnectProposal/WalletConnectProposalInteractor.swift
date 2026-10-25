import UIKit
import WalletConnectSign
import RobinHood
import SSFModels

protocol WalletConnectProposalInteractorOutput: AnyObject {
    func didReceive(walletsResult: Result<[MetaAccountModel], Error>)
    func didReceive(chainsResult: Result<[SSFModels.ChainModel], Error>)
}

final class WalletConnectProposalInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectProposalInteractorOutput?

    private let walletConnect: WalletConnectService
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    init(
        walletConnect: WalletConnectService,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.walletConnect = walletConnect
        self.walletRepository = walletRepository
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
    }

    // MARK: - Private methods

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

// MARK: - WalletConnectProposalInteractorInput

extension WalletConnectProposalInteractor: WalletConnectProposalInteractorInput {
    func setup(with output: WalletConnectProposalInteractorOutput) {
        self.output = output
        fetchWallets()
        fetchChainModels()
    }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        try await walletConnect.submit(proposalDecision: proposalDecision)
    }

    func submitDisconnect(topic: String) async throws {
        try await walletConnect.disconnect(topic: topic)
    }
}
