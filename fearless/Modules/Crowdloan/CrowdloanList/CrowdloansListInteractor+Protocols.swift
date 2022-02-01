import Foundation
import RobinHood

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    func setup() {
        guard let chain = settings.value else {
            presenter.didReceiveSelectedChain(result: .failure(
                PersistentValueSettingsError.missingValue
            ))
            return
        }

        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            presenter.didReceiveAccountInfo(
                result: .failure(ChainAccountFetchingError.accountNotExists)
            )
            return
        }

        setup(with: accountId, chain: chain)
    }

    func refresh() {
        guard let chain = settings.value else {
            presenter.didReceiveSelectedChain(result: .failure(
                PersistentValueSettingsError.missingValue
            ))
            return
        }

        refresh(with: chain)
    }

    func saveSelected(chainModel: ChainModel) {
        if settings.value?.chainId != chainModel.chainId {
            clear()

            settings.save(value: chainModel, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case .success:
                    self?.handleSelectionChange(to: chainModel)
                case let .failure(error):
                    self?.presenter.didReceiveSelectedChain(result: .failure(error))
                }
            }
        }
    }

    func becomeOnline() {
        guard let chain = settings.value else {
            return
        }

        becomeOnline(with: chain)
    }

    func putOffline() {
        guard let chain = settings.value else {
            return
        }

        putOffline(with: chain)
    }
}

extension CrowdloanListInteractor: CrowdloanLocalStorageSubscriber, CrowdloanLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId: ChainModel.Id) {
        if let chain = settings.value, chain.chainId == chainId {
            provideCrowdloans(for: chain)
            presenter.didReceiveBlockNumber(result: result)
        }
    }
}

extension CrowdloanListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) {
        if let chain = settings.value, chain.chainId == chainId {
            logger?.debug("Did receive balance for accountId: \(accountId.toHex()))")
            presenter.didReceiveAccountInfo(result: result)
        }
    }
}
