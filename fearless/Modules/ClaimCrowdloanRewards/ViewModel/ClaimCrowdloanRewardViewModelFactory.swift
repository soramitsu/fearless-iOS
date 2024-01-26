import Foundation
import SSFModels
import SoraFoundation

protocol ClaimCrowdloanRewardViewModelFactoryProtocol {
    func buildViewModel(
        vestingSchedule: VestingSchedule?,
        balanceLocks: [LockProtocol]?,
        locale: Locale,
        priceData: PriceData?,
        currentBlock: UInt32?
    ) -> ClaimCrowdloanRewardsViewModel

    func buildViewModel(
        vesting: VestingVesting?,
        balanceLocks: [LockProtocol]?,
        locale: Locale,
        priceData: PriceData?,
        currentBlock: UInt32?
    ) -> ClaimCrowdloanRewardsViewModel

    func createStakedAmountViewModel() -> LocalizableResource<StakeAmountViewModel>

    func buildHintViewModel() -> LocalizableResource<TitleIconViewModel?>
}

final class ClaimCrowdloanRewardViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
    }
}

extension ClaimCrowdloanRewardViewModelFactory: ClaimCrowdloanRewardViewModelFactoryProtocol {
    func buildViewModel(
        vesting: VestingVesting?,
        balanceLocks: [LockProtocol]?,
        locale: Locale,
        priceData: PriceData?,
        currentBlock: UInt32?
    ) -> ClaimCrowdloanRewardsViewModel {
        let totalRewardsValue = vesting.map { vesting in
            let lockedValue = Decimal.fromSubstrateAmount(vesting.locked ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return lockedValue
        } ?? .zero

        let totalRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            totalRewardsValue,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let lockedRewardsValue = balanceLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.map { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero
        let lockedRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            lockedRewardsValue,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let claimableRewards = vesting.map { vesting in
            let startVestingBlock = Decimal(vesting.startingBlock.or(0))
            let lockedDecimal = Decimal.fromSubstrateAmount(vesting.locked.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)
            let perBlockDecimal = Decimal.fromSubstrateAmount(vesting.perBlock.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)
            let totalPeriodLength = lockedDecimal / perBlockDecimal
            let finishVestingBlock = startVestingBlock + totalPeriodLength
            let currentBlockDecimal = Decimal(currentBlock.or(.zero))
            let periodRate = min((currentBlockDecimal - startVestingBlock) / (finishVestingBlock - startVestingBlock), 1.0)
            let totalAvailableForNow = periodRate * totalRewardsValue

            return lockedRewardsValue - (totalRewardsValue - totalAvailableForNow)
        } ?? .zero

        let claimableRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            claimableRewards,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return ClaimCrowdloanRewardsViewModel(
            totalRewardsViewModel: totalRewardsViewModel.value(for: locale),
            claimableRewardsViewModel: claimableRewardsViewModel.value(for: locale),
            lockedRewardsViewModel: lockedRewardsViewModel.value(for: locale)
        )
    }

    func buildViewModel(
        vestingSchedule: VestingSchedule?,
        balanceLocks: [LockProtocol]?,
        locale: Locale,
        priceData: PriceData?,
        currentBlock: UInt32?
    ) -> ClaimCrowdloanRewardsViewModel {
        let totalRewardsValue = vestingSchedule.map { vestingSchedule in
            let periodsDecimal = Decimal(vestingSchedule.periodCount ?? 0)
            let perPeriodDecimal = Decimal.fromSubstrateAmount(vestingSchedule.perPeriod ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return periodsDecimal * perPeriodDecimal
        } ?? .zero

        let totalRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            totalRewardsValue,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let lockedRewardsValue = balanceLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.map { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero
        let lockedRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            lockedRewardsValue,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        let claimableRewards = vestingSchedule.map { vestingSchedule in
            let startVestingBlock = Decimal(vestingSchedule.start.or(0))
            let totalPeriodLength = Decimal(vestingSchedule.period.or(0) * vestingSchedule.periodCount.or(0))
            let currentBlockDecimal = Decimal(currentBlock.or(0))
            let finishVestingBlock: Decimal = startVestingBlock + totalPeriodLength
            let periodRate = (currentBlockDecimal - startVestingBlock) / (finishVestingBlock - startVestingBlock)
            let totalAvailableForNow = periodRate * totalRewardsValue

            return lockedRewardsValue - (totalRewardsValue - totalAvailableForNow)
        } ?? .zero

        let claimableRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            claimableRewards,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return ClaimCrowdloanRewardsViewModel(
            totalRewardsViewModel: totalRewardsViewModel.value(for: locale),
            claimableRewardsViewModel: claimableRewardsViewModel.value(for: locale),
            lockedRewardsViewModel: lockedRewardsViewModel.value(for: locale)
        )
    }

    func createStakedAmountViewModel() -> LocalizableResource<StakeAmountViewModel> {
        let iconViewModel = chainAsset.asset.displayInfo.icon.map { RemoteImageViewModel(url: $0) }
        let symbol = chainAsset.asset.symbol.uppercased()
        return LocalizableResource { [weak self] _ in
            let stakedAmountAttributedString = NSMutableAttributedString(string: symbol)

            return StakeAmountViewModel(
                amountTitle: stakedAmountAttributedString,
                iconViewModel: iconViewModel,
                color: self?.chainAsset.asset.color
            )
        }
    }

    func buildHintViewModel() -> LocalizableResource<TitleIconViewModel?> {
        LocalizableResource { _ in
            TitleIconViewModel(
                title: "WARNING: We use basic formula for rewards calculation. We cannot guarantee proper calculation for all parachains. Before claim please visit parachain website and check your rewards.",
                icon: R.image.iconWarning()!
            )
        }
    }
}
