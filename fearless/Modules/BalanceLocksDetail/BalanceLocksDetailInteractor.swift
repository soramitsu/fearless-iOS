import UIKit
import SSFModels

final class BalanceLocksDetailInteractor {
    // MARK: - Private properties

    private weak var output: BalanceLocksDetailInteractorOutput?
    private let storageRequestPerformer: StorageRequestPerformer
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        storageRequestPerformer: StorageRequestPerformer
    ) {
        self.storageRequestPerformer = storageRequestPerformer
        self.wallet = wallet
        self.chainAsset = chainAsset
    }

    private func fetchStakingLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        Task {
            let request = StakingLedgerRequest(accountId: accountId)
            do {
                let ledger: StakingLedger? = try await storageRequestPerformer.performRequest(request)
                print("ledger: \(ledger)")
            } catch {
                print("ledger error: \(error)")
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
                print("nomination pools member: \(poolMember)")
            } catch {
                print("nomination pools member error: \(error)")
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
    }
}
