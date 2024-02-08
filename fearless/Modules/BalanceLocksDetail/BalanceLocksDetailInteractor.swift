import UIKit
import SSFModels

final class BalanceLocksDetailInteractor {
    // MARK: - Private properties

    private weak var output: BalanceLocksDetailInteractorOutput?
    private let storageRequestPerformer: StorageRequestPerformer
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let crowdloanService: CrowdloanService
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        storageRequestPerformer: StorageRequestPerformer,
        crowdloanService: CrowdloanService,
        priceLocalSubscriber: PriceLocalStorageSubscriber
    ) {
        self.storageRequestPerformer = storageRequestPerformer
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.crowdloanService = crowdloanService
        self.priceLocalSubscriber = priceLocalSubscriber
    }

    private func fetchStakingLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            let request = StakingLedgerRequest(accountId: accountId)
            do {
                let ledger: StakingLedger? = try await storageRequestPerformer.performRequest(request)
                output?.didReceiveStakingLedger(ledger)
            } catch {
                output?.didReceiveStakingLedgerError(error)
            }
        }
    }

    private func fetchNominationPoolLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            let request = NominationPoolsPoolMembersRequest(accountId: accountId)
            do {
                let poolMember: StakingPoolMember? = try await storageRequestPerformer.performRequest(request)
                output?.didReceiveStakingPoolMember(poolMember)
            } catch {
                output?.didReceiveStakingPoolError(error)
            }
        }
    }

    private func fetchBalanceLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            let request = BalancesLocksRequest(accountId: accountId)
            do {
                let balanceLocks: BalanceLocks? = try await storageRequestPerformer.performRequest(request)
                output?.didReceiveBalanceLocks(balanceLocks)
            } catch {
                output?.didReceiveBalanceLocksError(error)
            }
        }
    }

    private func fetchCrowdloansInfo() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            do {
                let contributions = try await crowdloanService.fetchContributions(accountId: accountId)
                output?.didReceiveCrowdloanContributions(contributions)
            } catch {
                output?.didReceiveCrowdloanContributionsError(error)
            }
        }
    }

    private func fetchVestings() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            output?.didReceiveVestingScheduleError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            let request = VestingVestingRequest(accountId: accountId)

            do {
                let vesting: [VestingVesting]? = try await storageRequestPerformer.performRequest(request)
                await MainActor.run(body: {
                    output?.didReceiveVestingVesting(vesting?.first)
                })
            } catch {
                await MainActor.run(body: {
                    output?.didReceiveVestingVestingError(error)
                })
            }
        }

        Task {
            let request = VestingSchedulesRequest(accountId: accountId)

            do {
                let vestingSchedule: [VestingSchedule]? = try await storageRequestPerformer.performRequest(request)
                await MainActor.run(body: {
                    output?.didReceiveVestingSchedule(vestingSchedule?.first)
                })
            } catch {
                await MainActor.run(body: {
                    output?.didReceiveVestingScheduleError(error)
                })
            }
        }
    }

    private func fetchCurrentEra() {}
}

// MARK: - BalanceLocksDetailInteractorInput

extension BalanceLocksDetailInteractor: BalanceLocksDetailInteractorInput {
    func setup(with output: BalanceLocksDetailInteractorOutput) {
        self.output = output

        fetchStakingLocks()
        fetchNominationPoolLocks()
        fetchBalanceLocks()
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
