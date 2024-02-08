import Foundation
import SSFModels
import SoraFoundation
import BigInt

protocol BalanceLockDetailViewModelFactory {
    func buildStakingLocksViewModel(
        stakingLedger: StakingLedger,
        priceData: PriceData?,
        activeEra: EraIndex
    ) -> BalanceLocksDetailStakingViewModel
    func buildPoolLocksViewModel(
        stakingPoolMember: StakingPoolMember,
        priceData: PriceData?,
        activeEra: EraIndex
    ) -> BalanceLocksDetailPoolViewModel
    func buildLiquidityPoolLocksViewModel() -> TitleMultiValueViewModel?
    func buildGovernanceLocksViewModel(
        balanceLocks: BalanceLocks,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildCrowdloanLocksViewModel(
        crowdloanConbibutions: CrowdloanContributionDict,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildVestingLocksViewModel(
        vesting: VestingVesting?,
        vestingSchedule: VestingSchedule?,
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
        stakingLedger: StakingLedger,
        priceData: PriceData?,
        activeEra: EraIndex
    ) -> BalanceLocksDetailStakingViewModel {
        let precision = Int16(chainAsset.asset.precision)

        let stakedDecimal = Decimal.fromSubstrateAmount(
            stakingLedger.active,
            precision: precision
        ).or(.zero)
        let stakedViewModel = balanceViewModelFactory.balanceFromPrice(
            stakedDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let unstakingValue = stakingLedger
            .unbondings(inEra: activeEra).map { $0.value }.reduce(0, +)
        let unstakingDecimal = Decimal.fromSubstrateAmount(
            unstakingValue,
            precision: precision
        ).or(.zero)
        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(
            unstakingDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let redeemableDecimal = Decimal.fromSubstrateAmount(
            stakingLedger.redeemable(inEra: activeEra),
            precision: precision
        ).or(.zero)
        let redeemableViewModel = balanceViewModelFactory.balanceFromPrice(
            redeemableDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return BalanceLocksDetailStakingViewModel(
            stakedViewModel: stakedViewModel,
            unstakingViewModel: unstakingViewModel,
            redeemableViewModel: redeemableViewModel
        )
    }

    func buildPoolLocksViewModel(
        stakingPoolMember: StakingPoolMember,
        priceData: PriceData?,
        activeEra: EraIndex
    ) -> BalanceLocksDetailPoolViewModel {
        let precision = Int16(chainAsset.asset.precision)
        let bondedDecimal = Decimal.fromSubstrateAmount(
            stakingPoolMember.points,
            precision: precision
        ).or(.zero)
        let stakedViewModel = balanceViewModelFactory.balanceFromPrice(bondedDecimal, priceData: priceData, usageCase: .detailsCrypto)

        let unstakingValue = stakingPoolMember
            .unbondings(inEra: activeEra).map { $0.value }.reduce(0, +)
        let unstakingDecimal = Decimal.fromSubstrateAmount(
            unstakingValue,
            precision: precision
        ).or(.zero)
        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(
            unstakingDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let redeemableDecimal = Decimal.fromSubstrateAmount(
            stakingPoolMember.redeemable(inEra: activeEra),
            precision: precision
        ).or(.zero)
        let redeemableViewModel = balanceViewModelFactory.balanceFromPrice(
            redeemableDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return BalanceLocksDetailPoolViewModel(
            stakedViewModel: stakedViewModel,
            unstakingViewModel: unstakingViewModel,
            redeemableViewModel: redeemableViewModel,
            claimableViewModel: nil
        )
    }

    func buildLiquidityPoolLocksViewModel() -> TitleMultiValueViewModel? {
        nil
    }

    func buildGovernanceLocksViewModel(balanceLocks: BalanceLocks, priceData: PriceData?) -> LocalizableResource<BalanceViewModelProtocol>? {
        let govLocked = balanceLocks.first(where: { $0.displayId == "pyconvot" })?.amount
        let govLockedDecimal = Decimal.fromSubstrateAmount(govLocked.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)

        return balanceViewModelFactory.balanceFromPrice(
            govLockedDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )
    }

    func buildCrowdloanLocksViewModel(
        crowdloanConbibutions: CrowdloanContributionDict,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        let totalLocked = crowdloanConbibutions.map { $0.value }.map { $0.balance }.reduce(0, +)
        let totalLockedDecimal = Decimal.fromSubstrateAmount(totalLocked, precision: Int16(chainAsset.asset.precision)).or(.zero)

        return balanceViewModelFactory.balanceFromPrice(
            totalLockedDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )
    }

    func buildVestingLocksViewModel(
        vesting: VestingVesting?,
        vestingSchedule: VestingSchedule?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        let vestingLocked = vesting.map { vesting in
            let lockedValue = Decimal.fromSubstrateAmount(vesting.locked ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return lockedValue
        } ?? .zero

        let vestingScheduleLocked = vestingSchedule.map { vestingSchedule in
            let periodsDecimal = Decimal(vestingSchedule.periodCount ?? 0)
            let perPeriodDecimal = Decimal.fromSubstrateAmount(vestingSchedule.perPeriod ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return periodsDecimal * perPeriodDecimal
        } ?? .zero

        let totalRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            vestingScheduleLocked + vestingLocked,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return totalRewardsViewModel
    }
}
