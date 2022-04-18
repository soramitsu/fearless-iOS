import UIKit
import RobinHood

final class ManageAssetsInteractor {
    weak var presenter: ManageAssetsInteractorOutputProtocol?

    private var selectedMetaAccount: MetaAccountModel
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol

    private var assetIdsEnabled: [String]?
    private var sortKeys: [String]?

    init(
        selectedMetaAccount: MetaAccountModel,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
    }

    private func fetchChainsAndSubscribeBalance() {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            presenter?.didReceiveChains(result: .success(chains))
            subscribeToAccountInfo(for: chains)
        case let .failure(error):
            presenter?.didReceiveChains(result: .failure(error))
        case .none:
            presenter?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        accountInfoSubscriptionAdapter.subscribe(chains: chains, handler: self)
    }
}

extension ManageAssetsInteractor: ManageAssetsInteractorInputProtocol {
    func markUnused(chain: ChainModel) {
        chain.unused = true
        let saveOperation = chainRepository.saveOperation {
            [chain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            self?.fetchChainsAndSubscribeBalance()

            self?.eventCenter.notify(with: ChainsUpdatedEvent(updatedChains: [chain]))
        }

        operationQueue.addOperation(saveOperation)
    }

    func setup() {
        fetchChainsAndSubscribeBalance()

        presenter?.didReceiveSortOrder(selectedMetaAccount.assetKeysOrder)
        presenter?.didReceiveAssetIdsEnabled(selectedMetaAccount.assetIdsEnabled)
    }

    func saveAssetsOrder(assets: [ChainAsset]) {
        let keys = assets.map { $0.uniqueKey(accountId: selectedMetaAccount.substrateAccountId) }
        sortKeys = keys

        presenter?.didReceiveSortOrder(keys)
    }

    func saveAssetIdsEnabled(_ assetIdsEnabled: [String]) {
        self.assetIdsEnabled = assetIdsEnabled

        presenter?.didReceiveAssetIdsEnabled(assetIdsEnabled)
    }

    func saveAllChanges() {
        var updatedAccount: MetaAccountModel?

        if let keys = sortKeys, keys != selectedMetaAccount.assetKeysOrder {
            updatedAccount = selectedMetaAccount.replacingAssetKeysOrder(keys)
        }

        if let assetIdsEnabled = assetIdsEnabled, assetIdsEnabled != selectedMetaAccount.assetIdsEnabled {
            updatedAccount = selectedMetaAccount.replacingAssetIdsEnabled(assetIdsEnabled)
        }

        if let updatedAccount = updatedAccount {
            let saveOperation = accountRepository.saveOperation {
                [updatedAccount]
            } _: {
                []
            }

            saveOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    self?.presenter?.saveDidComplete()

                    SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                        switch result {
                        case let .success(account):
                            self?.eventCenter.notify(with: AssetsListChangedEvent(account: account))
                        case .failure:
                            break
                        }
                    }
                }
            }

            operationQueue.addOperation(saveOperation)
        }
    }
}

extension ManageAssetsInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainId)
    }
}
