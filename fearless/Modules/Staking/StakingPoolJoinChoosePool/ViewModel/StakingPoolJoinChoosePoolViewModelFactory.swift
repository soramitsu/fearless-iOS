import Foundation

protocol StakingPoolJoinChoosePoolViewModelFactoryProtocol {
    func buildCellViewModels(
        pools: [StakingPool]?,
        locale: Locale,
        cellsDelegate: StakingPoolListTableCellModelDelegate?,
        selectedPoolId: String?
    ) -> [StakingPoolListTableCellModel]
}

final class StakingPoolJoinChoosePoolViewModelFactory {
    let chainAsset: ChainAsset
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

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
        selectedPoolId: String?
    ) -> [StakingPoolListTableCellModel] {
        guard let pools = pools else {
            return []
        }

        return pools.compactMap { pool -> StakingPoolListTableCellModel in
            let membersCountString = R.string.localizable.poolStakingChoosepoolMembersCountTitle(
                Int(pool.info.memberCounter),
                preferredLanguages: locale.rLanguages
            )

            let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo)
            let amountDecimal = Decimal.fromSubstrateAmount(
                pool.info.points,
                precision: Int16(chainAsset.asset.precision)
            ) ?? .zero
            let amountString = tokenFormatter.value(for: locale).stringFromDecimal(amountDecimal) ?? ""
            let stakedString = R.string.localizable.poolStakingChoosepoolStakedTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSAttributedString(string: stakedString)

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
