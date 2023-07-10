import Foundation
import SSFModels

protocol StakingPoolJoinChoosePoolViewModelFactoryProtocol {
    func buildCellViewModels(
        pools: [StakingPool]?,
        locale: Locale,
        cellsDelegate: StakingPoolListTableCellModelDelegate?,
        selectedPoolId: String?,
        sort: PoolSortOption
    ) -> [StakingPoolListTableCellModel]
}

final class StakingPoolJoinChoosePoolViewModelFactory {
    private let chainAsset: ChainAsset
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        chainAsset: ChainAsset,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }
}

extension StakingPoolJoinChoosePoolViewModelFactory: StakingPoolJoinChoosePoolViewModelFactoryProtocol {
    func buildCellViewModels(
        pools: [StakingPool]?,
        locale: Locale,
        cellsDelegate: StakingPoolListTableCellModelDelegate?,
        selectedPoolId: String?,
        sort: PoolSortOption
    ) -> [StakingPoolListTableCellModel] {
        guard let pools = pools else {
            return []
        }

        let openPools = pools.filter { $0.info.state == .open }

        let sortedPools = openPools.sorted { pool1, pool2 in
            switch sort {
            case .totalStake:
                return pool1.info.points < pool2.info.points
            case .numberOfMembers:
                return pool1.info.memberCounter < pool2.info.memberCounter
            }
        }

        return sortedPools.compactMap { pool -> StakingPoolListTableCellModel in
            let membersCountString = R.string.localizable.poolStakingChoosepoolMembersCountTitle(
                Int(pool.info.memberCounter),
                preferredLanguages: locale.rLanguages
            )

            let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .detailsCrypto)
            let amountDecimal = Decimal.fromSubstrateAmount(
                pool.info.points,
                precision: Int16(chainAsset.asset.precision)
            ) ?? .zero
            let amountString = tokenFormatter.value(for: locale).stringFromDecimal(amountDecimal) ?? ""
            let stakedString = R.string.localizable.poolStakingChoosepoolStakedTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorColdGreen() as Any,
                range: (stakedString as NSString).range(of: amountString)
            )

            let name = pool.name.count > 0 ? pool.name : pool.id
            return StakingPoolListTableCellModel(
                isSelected: selectedPoolId == pool.id,
                poolName: name,
                membersCountString: membersCountString,
                stakedAmountAttributedString: stakedAmountAttributedString,
                poolId: pool.id,
                delegate: cellsDelegate
            )
        }
    }
}
