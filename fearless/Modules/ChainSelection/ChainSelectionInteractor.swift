import UIKit
import RobinHood
import SSFModels

final class ChainSelectionInteractor {
    weak var presenter: ChainSelectionInteractorOutputProtocol!

    private let selectedMetaAccount: MetaAccountModel
    private let repository: AnyDataProviderRepository<ChainModel>
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationQueue: OperationQueue
    private let showBalances: Bool
    private let chainModels: [ChainModel]?

    private var accountInfoProviders: [AnyDataProvider<DecodedAccountInfo>]?

    init(
        selectedMetaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<ChainModel>,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationQueue: OperationQueue,
        showBalances: Bool,
        chainModels: [ChainModel]?
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.repository = repository
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationQueue = operationQueue
        self.showBalances = showBalances
        self.chainModels = chainModels
    }

    private func fetchChainsAndSubscribeBalance() {
        if let chainModels = chainModels {
            handleChains(result: .success(chainModels))
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let result: Result<[ChainModel], Error>
            do {
                let chains = try await repository.fetchAllAsync()
                result = .success(chains)
            } catch {
                result = .failure(error)
            }
            await MainActor.run { [weak self] in
                self?.handleChains(result: result)
            }
        }
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            presenter.didReceiveChains(result: .success(chains))
            subscribeToAccountInfo(for: chains)
        case let .failure(error):
            presenter.didReceiveChains(result: .failure(error))
        case .none:
            presenter.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        guard showBalances else { return }
        let chainAsset = chains.map(\.chainAssets).reduce([], +)
        accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainAsset, handler: self)
    }
}

extension ChainSelectionInteractor: ChainSelectionInteractorInputProtocol {
    func setup() {
        fetchChainsAndSubscribeBalance()
    }
}

extension ChainSelectionInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        let key = chainAsset.uniqueKey(accountId: accountId)
        presenter.didReceiveAccountInfo(result: result, for: key)
    }
}
