import Foundation
import SSFModels
import SoraFoundation
import BigInt

protocol BalanceLockDetailViewModelFactory {
    func buildStakingLocksViewModel(
        stakingLedger: StakingLedger?,
        priceData: PriceData?,
        activeEra: EraIndex?
    ) -> BalanceLocksDetailStakingViewModel?
    func buildPoolLocksViewModel(
        stakingPoolMember: StakingPoolMember?,
        priceData: PriceData?,
        activeEra: EraIndex?
    ) -> BalanceLocksDetailPoolViewModel?
    func buildLiquidityPoolLocksViewModel() -> TitleMultiValueViewModel?
    func buildGovernanceLocksViewModel(
        balanceLocks: BalanceLocks?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildCrowdloanLocksViewModel(
        crowdloanConbibutions: CrowdloanContributionDict?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildVestingLocksViewModel(
        vesting: VestingVesting?,
        vestingSchedule: VestingSchedule?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildTotalLocksViewModel(
        stakingLedger: StakingLedger?,
        stakingPoolMember: StakingPoolMember?,
        balanceLocks: BalanceLocks?,
        crowdloanConbibutions: CrowdloanContributionDict?,
        vesting: VestingVesting?,
        vestingSchedule: VestingSchedule?,
        activeEra: EraIndex?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
}

final class BalanceLockDetailViewModelFactoryDefault: BalanceLockDetailViewModelFactory {
    func buildTotalLocksViewModel(
        stakingLedger: StakingLedger?,
        stakingPoolMember: StakingPoolMember?,
        balanceLocks: BalanceLocks?,
        crowdloanConbibutions: CrowdloanContributionDict?,
        vesting: VestingVesting?,
        vestingSchedule: VestingSchedule?,
        activeEra: EraIndex?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        let locked = [
            calculateStakingStakedLock(stakingLedger: stakingLedger),
            calculateStakingUnstakingLock(stakingLedger: stakingLedger, activeEra: activeEra),
            calculateStakingRedeemableLock(stakingLedger: stakingLedger, activeEra: activeEra),
            calculatePoolStakedLocked(stakingPoolMember: stakingPoolMember),
            calculatePoolUnstakingLocked(stakingPoolMember: stakingPoolMember, activeEra: activeEra),
            calculatePoolRedeemableLocked(stakingPoolMember: stakingPoolMember, activeEra: activeEra),
            calculateGovernanceLocked(balanceLocks: balanceLocks),
            calculateCrowdloanLocked(crowdloanConbibutions: crowdloanConbibutions),
            calculateVestingLocked(vesting: vesting, vestingSchedule: vestingSchedule)
        ].reduce(0,+)

        return balanceViewModelFactory.balanceFromPrice(
            locked,
            priceData: priceData,
            usageCase: .detailsCrypto
        )
    }

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset

    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol, chainAsset: ChainAsset) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
    }

    func buildStakingLocksViewModel(
        stakingLedger: StakingLedger?,
        priceData: PriceData?,
        activeEra: EraIndex?
    ) -> BalanceLocksDetailStakingViewModel? {
        let stakedDecimal = calculateStakingStakedLock(stakingLedger: stakingLedger)
        let stakedViewModel = balanceViewModelFactory.balanceFromPrice(
            stakedDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let unstakingDecimal = calculateStakingUnstakingLock(stakingLedger: stakingLedger, activeEra: activeEra)
        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(
            unstakingDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let redeemableDecimal = calculateStakingRedeemableLock(stakingLedger: stakingLedger, activeEra: activeEra)
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
        stakingPoolMember: StakingPoolMember?,
        priceData: PriceData?,
        activeEra: EraIndex?
    ) -> BalanceLocksDetailPoolViewModel? {
        let bondedDecimal = calculatePoolStakedLocked(stakingPoolMember: stakingPoolMember)
        let stakedViewModel = balanceViewModelFactory.balanceFromPrice(bondedDecimal, priceData: priceData, usageCase: .detailsCrypto)

        let unstakingDecimal = calculatePoolUnstakingLocked(stakingPoolMember: stakingPoolMember, activeEra: activeEra)
        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(
            unstakingDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let redeemableDecimal = calculatePoolRedeemableLocked(stakingPoolMember: stakingPoolMember, activeEra: activeEra)
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

    func buildGovernanceLocksViewModel(balanceLocks: BalanceLocks?, priceData: PriceData?) -> LocalizableResource<BalanceViewModelProtocol>? {
        let govLockedDecimal = calculateGovernanceLocked(balanceLocks: balanceLocks)

        return balanceViewModelFactory.balanceFromPrice(
            govLockedDecimal,
            priceData: priceData,
            usageCase: .detailsCrypto
        )
    }

    func buildCrowdloanLocksViewModel(
        crowdloanConbibutions: CrowdloanContributionDict?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        let totalLockedDecimal = calculateCrowdloanLocked(crowdloanConbibutions: crowdloanConbibutions)

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
        let locked = calculateVestingLocked(vesting: vesting, vestingSchedule: vestingSchedule)

        let totalRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            locked,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return totalRewardsViewModel
    }

    // MARK: Private functions

    private func calculateStakingStakedLock(
        stakingLedger: StakingLedger?
    ) -> Decimal {
        let precision = Int16(chainAsset.asset.precision)
        let active = stakingLedger?.active
        return Decimal.fromSubstrateAmount(
            active.or(.zero),
            precision: precision
        ).or(.zero)
    }

    private func calculateStakingUnstakingLock(
        stakingLedger: StakingLedger?,
        activeEra: EraIndex?
    ) -> Decimal {
        guard let activeEra else {
            return .zero
        }

        let precision = Int16(chainAsset.asset.precision)
        let unstakingValue = stakingLedger?
            .unbondings(inEra: activeEra)
            .map { $0.value }
            .reduce(0, +)

        return Decimal.fromSubstrateAmount(
            unstakingValue.or(.zero),
            precision: precision
        ).or(.zero)
    }

    private func calculateStakingRedeemableLock(
        stakingLedger: StakingLedger?,
        activeEra: EraIndex?
    ) -> Decimal {
        guard let activeEra else {
            return .zero
        }

        let precision = Int16(chainAsset.asset.precision)
        let redeemable = stakingLedger?.redeemable(inEra: activeEra)

        return Decimal.fromSubstrateAmount(
            redeemable.or(.zero),
            precision: precision
        ).or(.zero)
    }

    func calculatePoolStakedLocked(
        stakingPoolMember: StakingPoolMember?
    ) -> Decimal {
        let precision = Int16(chainAsset.asset.precision)
        let points = stakingPoolMember?.points

        return Decimal.fromSubstrateAmount(
            points.or(.zero),
            precision: precision
        ).or(.zero)
    }

    func calculatePoolUnstakingLocked(
        stakingPoolMember: StakingPoolMember?,
        activeEra: EraIndex?
    ) -> Decimal {
        guard let activeEra else {
            return .zero
        }

        let precision = Int16(chainAsset.asset.precision)
        let unstakingValue = stakingPoolMember?
            .unbondings(inEra: activeEra)
            .map { $0.value }
            .reduce(0, +)

        return Decimal.fromSubstrateAmount(
            unstakingValue.or(.zero),
            precision: precision
        ).or(.zero)
    }

    func calculatePoolRedeemableLocked(
        stakingPoolMember: StakingPoolMember?,
        activeEra: EraIndex?
    ) -> Decimal {
        guard let activeEra else {
            return .zero
        }

        let precision = Int16(chainAsset.asset.precision)
        let redeemable = stakingPoolMember?.redeemable(inEra: activeEra)
        return Decimal.fromSubstrateAmount(
            redeemable.or(.zero),
            precision: precision
        ).or(.zero)
    }

    private func calculateGovernanceLocked(balanceLocks: BalanceLocks?) -> Decimal {
        let govLocked = balanceLocks?.first(where: { $0.displayId == "pyconvot" })?.amount
        return Decimal.fromSubstrateAmount(govLocked.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    private func calculateCrowdloanLocked(crowdloanConbibutions: CrowdloanContributionDict?) -> Decimal {
        let totalLocked = crowdloanConbibutions?.map { $0.value }.map { $0.balance }.reduce(0, +)
        return Decimal.fromSubstrateAmount(totalLocked.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    private func calculateVestingLocked(
        vesting: VestingVesting?,
        vestingSchedule: VestingSchedule?
    ) -> Decimal {
        let vestingLocked = vesting.map { vesting in
            let lockedValue = Decimal.fromSubstrateAmount(vesting.locked ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return lockedValue
        } ?? .zero

        let vestingScheduleLocked = vestingSchedule.map { vestingSchedule in
            let periodsDecimal = Decimal(vestingSchedule.periodCount ?? 0)
            let perPeriodDecimal = Decimal.fromSubstrateAmount(vestingSchedule.perPeriod ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return periodsDecimal * perPeriodDecimal
        } ?? .zero

        return vestingScheduleLocked + vestingLocked
    }
}
