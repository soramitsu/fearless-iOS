import Foundation
import UIKit
import SSFModels

protocol StakingPoolInfoViewModelFactoryProtocol {
    func buildViewModel(
        validators: YourValidatorsModel,
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
        validators: YourValidatorsModel,
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
        let stakedAmountViewModel = balanceViewModelFactory.balanceFromPrice(staked, priceData: priceData, usageCase: .detailsCrypto)
        let validatorsCountAttributedString = NSMutableAttributedString(string: "\(validators.allValidators.count)" + "    ")

        let imageAttachment = NSTextAttachment()
        imageAttachment.image = R.image.iconDetails()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: 0,
            width: 6,
            height: 10
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
            bouncerName: try? roles.bouncer?.toAddress(using: chainAsset.chain.chainFormat),
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
