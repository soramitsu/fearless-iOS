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

    private func fetchStakingLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            do {
                let stakingLocks: StakingLocks? = try await balanceLocksFetching.fetchStakingLocks(for: accountId)
                output?.didReceiveStakingLocks(stakingLocks)
            } catch {
                output?.didReceiveStakingLocksError(error)
            }
        }
    }

    private func fetchNominationPoolLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            do {
                let nominationPoolLocks: StakingLocks? = try await balanceLocksFetching.fetchNominationPoolLocks(for: accountId)
                output?.didReceiveNominationPoolLocks(nominationPoolLocks)
            } catch {
                output?.didReceiveNominationPoolLocksError(error)
            }
        }
    }

    private func fetchGovernanceLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            do {
                let governanceLocks: Decimal? = try await balanceLocksFetching.fetchGovernanceLocks(for: accountId)
                output?.didReceiveGovernanceLocks(governanceLocks)
            } catch {
                output?.didReceiveGovernanceLocksError(error)
            }
        }
    }

    private func fetchCrowdloansInfo() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            do {
                let crowdloanLocks = try await balanceLocksFetching.fetchCrowdloanLocks(for: accountId)
                output?.didReceiveCrowdloanLocks(crowdloanLocks)
            } catch {
                output?.didReceiveCrowdloanLocksError(error)
            }
        }
    }

    private func fetchVestings() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            output?.didReceiveVestingLocksError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let vestingLocks = try await balanceLocksFetching.fetchVestingLocks(for: accountId, currencyId: chainAsset.currencyId)
                output?.didReceiveVestingLocks(vestingLocks)
            } catch {
                output?.didReceiveVestingLocksError(error)
            }
        }
    }
}

// MARK: - BalanceLocksDetailInteractorInput

extension BalanceLocksDetailInteractor: BalanceLocksDetailInteractorInput {
    func setup(with output: BalanceLocksDetailInteractorOutput) {
        self.output = output

        fetchStakingLocks()
        fetchNominationPoolLocks()
        fetchGovernanceLocks()
        fetchCrowdloansInfo()
        fetchVestings()
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
