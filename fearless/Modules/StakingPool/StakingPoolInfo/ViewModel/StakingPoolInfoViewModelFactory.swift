import Foundation
import UIKit

protocol StakingPoolInfoViewModelFactoryProtocol {
    func buildViewModel(
        stashAccount: AccountId,
        electedValidators: [ElectedValidatorInfo],
        stakingPool: StakingPool,
        priceData: PriceData?,
        locale: Locale,
        roles: StakingPoolRoles,
        wallet: MetaAccountModel
    ) -> StakingPoolInfoViewModel

    func buildStatus(
        poolInfo: StakingPool,
        era: EraIndex?,
        nomination: Nomination?
    ) -> NominationViewStatus
}

final class StakingPoolInfoViewModelFactory {
    private let chainAsset: ChainAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(chainAsset: ChainAsset, balanceViewModelFactory: BalanceViewModelFactoryProtocol) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
    }
}

extension StakingPoolInfoViewModelFactory: StakingPoolInfoViewModelFactoryProtocol {
    func buildViewModel(
        stashAccount: AccountId,
        electedValidators: [ElectedValidatorInfo],
        stakingPool: StakingPool,
        priceData: PriceData?,
        locale: Locale,
        roles: StakingPoolRoles,
        wallet: MetaAccountModel
    ) -> StakingPoolInfoViewModel {
        let staked = Decimal.fromSubstrateAmount(
            stakingPool.info.points,
            precision: Int16(chainAsset.asset.precision)
        ) ?? 0.0
        let stakedAmountViewModel = balanceViewModelFactory.balanceFromPrice(staked, priceData: priceData)

        let selectedValidators = electedValidators.map { validator in
            validator.toSelected(for: try? stashAccount.toAddress(using: chainAsset.chain.chainFormat))
        }.filter { $0.isActive }

        let validatorsCountAttributedString = NSMutableAttributedString(string: "\(selectedValidators.count)" + "  ")

        let imageAttachment = NSTextAttachment()
        imageAttachment.image = R.image.dropTriangle()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: 3,
            width: 12,
            height: 6
        )

        let imageString = NSAttributedString(attachment: imageAttachment)
        validatorsCountAttributedString.append(imageString)

        let currentAccountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        return StakingPoolInfoViewModel(
            indexTitle: stakingPool.id,
            name: stakingPool.name,
            state: stakingPool.info.state.rawValue,
            stakedAmountViewModel: stakedAmountViewModel.value(for: locale),
            membersCountTitle: "\(stakingPool.info.memberCounter)",
            validatorsCountAttributedString: validatorsCountAttributedString,
            depositorName: try? roles.depositor.toAddress(using: chainAsset.chain.chainFormat),
            rootName: try? roles.root?.toAddress(using: chainAsset.chain.chainFormat),
            nominatorName: try? roles.nominator?.toAddress(using: chainAsset.chain.chainFormat),
            stateTogglerName: try? roles.stateToggler?.toAddress(using: chainAsset.chain.chainFormat),
            rolesChanged: roles != stakingPool.info.roles,
            userIsRoot: currentAccountId == stakingPool.info.roles.root
        )
    }

    func buildStatus(
        poolInfo: StakingPool,
        era: EraIndex?,
        nomination: Nomination?
    ) -> NominationViewStatus {
        var status: NominationViewStatus = .undefined
        switch poolInfo.info.state {
        case .open:
            guard let era = era else {
                break
            }

            if nomination?.targets.isNotEmpty == true {
                status = .active(era: era)
            } else {
                status = .validatorsNotSelected
            }
        case .blocked, .destroying:
            guard let era = era else {
                break
            }

            status = .inactive(era: era)
        }

        return status
    }
}
