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
        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                return
            }
            self?.output?.didReceive(chainsResult: result)
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
