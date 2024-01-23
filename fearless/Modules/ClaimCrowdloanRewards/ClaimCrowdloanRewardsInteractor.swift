import UIKit
import SSFUtils
import SSFModels
import RobinHood

final class ClaimCrowdloanRewardsInteractor {
    // MARK: - Private properties
    private weak var output: ClaimCrowdloanRewardsInteractorOutput?
    
    private let callFactory: SubstrateCallFactoryProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let balanceLocksProvider: BalanceLocksProviderProtocol
    
    init(
        callFactory: SubstrateCallFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        balanceLocksProvider: BalanceLocksProviderProtocol
    ) {
        self.callFactory = callFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.balanceLocksProvider = balanceLocksProvider
    }
    
    private func fetchBalanceLocks() {
        Task {
            do {
                let locks = try await balanceLocksProvider.fetchBalanceLocks(for: chainAsset, wallet: wallet)
                output?.didReceiveBalanceLocks(locks)
            } catch {
                output?.didReceiveBalanceLocksError(error)
            }
        }
    }
}

// MARK: - ClaimCrowdloanRewardsInteractorInput
extension ClaimCrowdloanRewardsInteractor: ClaimCrowdloanRewardsInteractorInput {
    func setup(with output: ClaimCrowdloanRewardsInteractorOutput) {
        self.output = output
        
        fetchBalanceLocks()
    }
}
