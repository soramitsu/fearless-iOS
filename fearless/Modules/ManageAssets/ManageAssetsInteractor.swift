import UIKit
import RobinHood

final class ManageAssetsInteractor {
    weak var presenter: ManageAssetsInteractorOutputProtocol?

    private var selectedMetaAccount: MetaAccountModel {
        didSet {
            presenter?.didReceiveWallet(selectedMetaAccount)
        }
    }

    private let chainModels: [ChainModel]
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol

    private var assetIdsEnabled: [String]?
    private var sortKeys: [String]?
    private var filterOptions: [FilterOption]?
    private var chainIdForFilter: ChainModel.Id?

    init(
        selectedMetaAccount: MetaAccountModel,
        chainModels: [ChainModel],
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainModels = chainModels
        self.accountRepository = accountRepository
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        chainIdForFilter = selectedMetaAccount.chainIdForFilter
    }

    private func handleChains(chains: [ChainModel]) {
        subscribeToAccountInfo(for: chains)
        presenter?.didReceiveChains(result: .success(chains))
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        let chainsAssets = chains.map(\.chainAssets).reduce([], +)
        accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainsAssets, handler: self)
    }

    private func save(
        _ updatedAccount: MetaAccountModel,
        needDismiss: Bool
    ) {
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            if needDismiss {
                DispatchQueue.main.async {
                    self?.presenter?.saveDidComplete()
                }
            }
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    DispatchQueue.main.async {
                        self?.selectedMetaAccount = account
                        self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                    }
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension ManageAssetsInteractor: ManageAssetsInteractorInputProtocol {
    func saveChainIdForFilter(_ chainId: ChainModel.Id?) {
        chainIdForFilter = chainId
    }

    func markUnused(chain: ChainModel) {
        var unusedChainIds = selectedMetaAccount.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = selectedMetaAccount.replacingUnusedChainIds(unusedChainIds)

        save(updatedAccount, needDismiss: false)
    }

    func saveFilter(_ options: [FilterOption]) {
        filterOptions = options
        presenter?.didReceiveFilterOptions(filterOptions)
    }

    func setup() {
        handleChains(chains: chainModels)
        presenter?.didReceiveAccount(selectedMetaAccount)
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
            if let accountForSave = updatedAccount {
                updatedAccount = accountForSave.replacingAssetIdsEnabled(assetIdsEnabled)
            } else {
                updatedAccount = selectedMetaAccount.replacingAssetIdsEnabled(assetIdsEnabled)
            }
        }

        if let filterOptions = filterOptions, filterOptions != selectedMetaAccount.assetFilterOptions {
            if let accountForSave = updatedAccount {
                updatedAccount = accountForSave.replacingAssetsFilterOptions(filterOptions)
            } else {
                updatedAccount = selectedMetaAccount.replacingAssetsFilterOptions(filterOptions)
            }
        }

        if chainIdForFilter != selectedMetaAccount.chainIdForFilter {
            if let accountForSave = updatedAccount {
                updatedAccount = accountForSave.replacingChainIdForFilter(chainIdForFilter)
            } else {
                updatedAccount = selectedMetaAccount.replacingChainIdForFilter(chainIdForFilter)
            }
        }

        if let updatedAccount = updatedAccount {
            save(updatedAccount, needDismiss: true)
        }
    }
}

extension ManageAssetsInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset.uniqueKey(accountId: accountId))
    }
}
