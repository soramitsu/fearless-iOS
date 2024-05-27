import UIKit
import SSFModels

final class BalanceLocksDetailInteractor {
    // MARK: - Private properties

    private weak var output: BalanceLocksDetailInteractorOutput?
    private let balanceLocksFetching: BalanceLocksFetching
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        balanceLocksFetching: BalanceLocksFetching,
        priceLocalSubscriber: PriceLocalStorageSubscriber
    ) {
        self.balanceLocksFetching = balanceLocksFetching
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.priceLocalSubscriber = priceLocalSubscriber
    }

    private func fetchStakingLocks() async {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        do {
            let stakingLocks: StakingLocks? = try await balanceLocksFetching.fetchStakingLocks(for: accountId)
            await output?.didReceiveStakingLocks(stakingLocks)
        } catch {
            await output?.didReceiveStakingLocksError(error)
        }
    }

    private func fetchNominationPoolLocks() async {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        do {
            let nominationPoolLocks: StakingLocks? = try await balanceLocksFetching.fetchNominationPoolLocks(for: accountId)
            await output?.didReceiveNominationPoolLocks(nominationPoolLocks)
        } catch {
            await output?.didReceiveNominationPoolLocksError(error)
        }
    }

    private func fetchGovernanceLocks() async {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        do {
            let governanceLocks: Decimal? = try await balanceLocksFetching.fetchGovernanceLocks(for: accountId)
            await output?.didReceiveGovernanceLocks(governanceLocks)
        } catch {
            await output?.didReceiveGovernanceLocksError(error)
        }
    }

    private func fetchCrowdloansInfo() async {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        do {
            let crowdloanLocks = try await balanceLocksFetching.fetchCrowdloanLocks(for: accountId)
            await output?.didReceiveCrowdloanLocks(crowdloanLocks)
        } catch {
            await output?.didReceiveCrowdloanLocksError(error)
        }
    }

    private func fetchVestings() async {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            await output?.didReceiveVestingLocksError(ChainAccountFetchingError.accountNotExists)
            return
        }

        do {
            let vestingLocks = try await balanceLocksFetching.fetchVestingLocks(for: accountId, currencyId: chainAsset.currencyId)
            await output?.didReceiveVestingLocks(vestingLocks)
        } catch {
            await output?.didReceiveVestingLocksError(error)
        }
    }

    private func fetchAssetFrozen() async {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            await output?.didReceiveAssetFrozenError(ChainAccountFetchingError.accountNotExists)
            return
        }

        do {
            let frozen = try await balanceLocksFetching.fetchAssetFrozen(for: accountId, currencyId: chainAsset.currencyId)
            await output?.didReceiveAssetFrozen(frozen)
        } catch {
            await output?.didReceiveAssetFrozenError(error)
        }
    }

    private func fetchAssetBlocked() async {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            await output?.didReceiveAssetBlockedError(ChainAccountFetchingError.accountNotExists)
            return
        }

        do {
            let blocked = try await balanceLocksFetching.fetchAssetBlocked(for: accountId, currencyId: chainAsset.currencyId)
            await output?.didReceiveAssetBlocked(blocked)
        } catch {
            await output?.didReceiveAssetBlockedError(error)
        }
    }
}

// MARK: - BalanceLocksDetailInteractorInput

extension BalanceLocksDetailInteractor: BalanceLocksDetailInteractorInput {
    func setup(with output: BalanceLocksDetailInteractorOutput) {
        self.output = output

        Task {
            await fetchStakingLocks()
            await fetchNominationPoolLocks()
            await fetchGovernanceLocks()
            await fetchCrowdloansInfo()
            await fetchVestings()
            await fetchAssetFrozen()
            await fetchAssetBlocked()
        }

        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
    }
}

extension BalanceLocksDetailInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        switch result {
        case let .success(price):
            output?.didReceivePrice(price)
        case let .failure(error):
            output?.didReceivePriceError(error)
        }
    }
}
