import UIKit
import SSFModels

final class BalanceLocksDetailInteractor {
    // MARK: - Private properties

    private weak var output: BalanceLocksDetailInteractorOutput?
    private let storageRequestPerformer: StorageRequestPerformer
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let crowdloanService: CrowdloanService

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        storageRequestPerformer: StorageRequestPerformer,
        crowdloanService: CrowdloanService
    ) {
        self.storageRequestPerformer = storageRequestPerformer
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.crowdloanService = crowdloanService
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
}

// MARK: - BalanceLocksDetailInteractorInput

extension BalanceLocksDetailInteractor: BalanceLocksDetailInteractorInput {
    func setup(with output: BalanceLocksDetailInteractorOutput) {
        self.output = output

        fetchStakingLocks()
        fetchNominationPoolLocks()
        fetchBalanceLocks()
        fetchCrowdloansInfo()
    }
}
