import Foundation

protocol BalanceLockDetailViewModelFactory {
    func buildStakingLocksViewModel(stakingLedger: StakingLedger) -> BalanceLocksDetailStakingViewModel
    func buildPoolLocksViewModel(stakingPoolMember: StakingPoolMember) -> BalanceLocksDetailStakingViewModel
    func buildLiquidityPoolLocksViewModel() -> TitleMultiValueViewModel?
    func buildGovernanceLocksViewModel(balanceLocks: BalanceLocks) -> TitleMultiValueViewModel?
    func buildCrowdloanLocksViewModel(crowdloanConbibutions: CrowdloanContributionDict) -> TitleMultiValueViewModel?
}

final class BalanceLockDetailViewModelFactoryDefault: BalanceLockDetailViewModelFactory {
    func buildStakingLocksViewModel(stakingLedger: StakingLedger) -> BalanceLocksDetailStakingViewModel {
        <#code#>
    }
    
    func buildPoolLocksViewModel(stakingPoolMember: StakingPoolMember) -> BalanceLocksDetailStakingViewModel {
        <#code#>
    }
    
    func buildLiquidityPoolLocksViewModel() -> TitleMultiValueViewModel? {
        <#code#>
    }
    
    func buildGovernanceLocksViewModel(balanceLocks: BalanceLocks) -> TitleMultiValueViewModel? {
        <#code#>
    }
    
    func buildCrowdloanLocksViewModel(crowdloanConbibutions: CrowdloanContributionDict) -> TitleMultiValueViewModel? {
        <#code#>
    }
    
    
}
