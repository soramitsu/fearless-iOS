import Foundation
import SSFModels
import SoraFoundation
import BigInt

protocol BalanceLockDetailViewModelFactory {
    func buildStakingLocksViewModel(
        stakingLocks: StakingLocks?,
        priceData: PriceData?
    ) -> BalanceLocksDetailStakingViewModel?
    func buildNominationPoolLocksViewModel(
        nominationPoolLocks: StakingLocks?,
        priceData: PriceData?
    ) -> BalanceLocksDetailPoolViewModel?
    func buildLiquidityPoolLocksViewModel() -> TitleMultiValueViewModel?
    func buildGovernanceLocksViewModel(
        governanceLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildCrowdloanLocksViewModel(
        crowdloanLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildVestingLocksViewModel(
        vestingLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildTotalLocksViewModel(
        stakingLocks: StakingLocks?,
        nominationPoolLocks: StakingLocks?,
        governanceLocks: Decimal?,
        crowdloanLocks: Decimal?,
        vestingLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
}

final class BalanceLockDetailViewModelFactoryDefault: BalanceLockDetailViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset

    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol, chainAsset: ChainAsset) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
    }

    func buildStakingLocksViewModel(
        stakingLocks: StakingLocks?,
        priceData: PriceData?
    ) -> BalanceLocksDetailStakingViewModel? {
        let stakedViewModel = balanceViewModelFactory.balanceFromPrice(
            (stakingLocks?.staked).or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(
            (stakingLocks?.unstaking).or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let redeemableViewModel = balanceViewModelFactory.balanceFromPrice(
            (stakingLocks?.redeemable).or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return BalanceLocksDetailStakingViewModel(
            stakedViewModel: stakedViewModel,
            unstakingViewModel: unstakingViewModel,
            redeemableViewModel: redeemableViewModel
        )
    }

    func buildNominationPoolLocksViewModel(
        nominationPoolLocks: StakingLocks?,
        priceData: PriceData?
    ) -> BalanceLocksDetailPoolViewModel? {
        let stakedViewModel = balanceViewModelFactory.balanceFromPrice(
            (nominationPoolLocks?.staked).or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(
            (nominationPoolLocks?.unstaking).or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let redeemableViewModel = balanceViewModelFactory.balanceFromPrice(
            (nominationPoolLocks?.redeemable).or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let claimableViewModel = balanceViewModelFactory.balanceFromPrice(
            (nominationPoolLocks?.claimable).or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return BalanceLocksDetailPoolViewModel(
            stakedViewModel: stakedViewModel,
            unstakingViewModel: unstakingViewModel,
            redeemableViewModel: redeemableViewModel,
            claimableViewModel: claimableViewModel
        )
    }

    func buildLiquidityPoolLocksViewModel() -> TitleMultiValueViewModel? {
        // Will be implemented within the LP's integration
        nil
    }

    func buildGovernanceLocksViewModel(
        governanceLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        balanceViewModelFactory.balanceFromPrice(
            governanceLocks.or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )
    }

    func buildCrowdloanLocksViewModel(
        crowdloanLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        balanceViewModelFactory.balanceFromPrice(
            crowdloanLocks.or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )
    }

    func buildVestingLocksViewModel(
        vestingLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        let totalRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            vestingLocks.or(.zero),
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return totalRewardsViewModel
    }

    func buildTotalLocksViewModel(
        stakingLocks: StakingLocks?,
        nominationPoolLocks: StakingLocks?,
        governanceLocks: Decimal?,
        crowdloanLocks: Decimal?,
        vestingLocks: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        let totalLocks = [
            (stakingLocks?.total).or(.zero),
            (nominationPoolLocks?.total).or(.zero),
            governanceLocks.or(.zero),
            crowdloanLocks.or(.zero),
            vestingLocks.or(.zero)
        ].reduce(0, +)

        return balanceViewModelFactory.balanceFromPrice(
            totalLocks,
            priceData: priceData,
            usageCase: .detailsCrypto
        )
    }
}
