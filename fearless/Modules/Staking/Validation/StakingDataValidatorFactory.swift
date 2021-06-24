import Foundation
import SoraFoundation
import IrohaCrypto

protocol StakingDataValidatingFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func canUnbond(amount: Decimal?, bonded: Decimal?, locale: Locale) -> DataValidating
    func canRebond(amount: Decimal?, unbonding: Decimal?, locale: Locale) -> DataValidating

    func has(controller: AccountItem?, for address: AccountAddress, locale: Locale) -> DataValidating
    func has(stash: AccountItem?, for address: AccountAddress, locale: Locale) -> DataValidating
    func electionClosed(_ electionStatus: ElectionStatus?, locale: Locale) -> DataValidating
    func unbondingsLimitNotReached(_ count: Int?, locale: Locale) -> DataValidating
    func controllerBalanceIsNotZero(_ balance: Decimal?, locale: Locale) -> DataValidating

    func canNominate(
        amount: Decimal?,
        minimalBalance: Decimal?,
        minNominatorBond: Decimal?,
        locale: Locale
    ) -> DataValidating

    func rewardIsHigherThanFee(
        reward: Decimal?,
        fee: Decimal?,
        locale: Locale
    ) -> DataValidating

    func stashIsNotKilledAfterUnbonding(
        amount: Decimal?,
        bonded: Decimal?,
        minimumAmount: Decimal?,
        locale: Locale
    ) -> DataValidating

    func ledgerNotExist(
        stakingLedger: StakingLedger?,
        addressType: SNAddressType,
        locale: Locale
    ) -> DataValidating

    func hasRedeemable(stakingLedger: StakingLedger?, in era: UInt32?, locale: Locale) -> DataValidating

    func maxNominatorsCountNotReached(
        counterForNominators: UInt32?,
        maxNominatorsCount: UInt32?,
        locale: Locale
    ) -> DataValidating
}

final class StakingDataValidatingFactory: StakingDataValidatingFactoryProtocol {
    weak var view: (ControllerBackedProtocol & Localizable)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: StakingErrorPresentable

    let balanceFactory: BalanceViewModelFactoryProtocol?

    init(presentable: StakingErrorPresentable, balanceFactory: BalanceViewModelFactoryProtocol? = nil) {
        self.presentable = presentable
        self.balanceFactory = balanceFactory
    }

    func canUnbond(amount: Decimal?, bonded: Decimal?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnbondingTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            if let amount = amount,
               let bonded = bonded {
                return amount <= bonded
            } else {
                return false
            }
        })
    }

    func canRebond(amount: Decimal?, unbonding: Decimal?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentRebondingTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            if let amount = amount,
               let unbonding = unbonding {
                return amount <= unbonding
            } else {
                return false
            }
        })
    }

    func has(controller: AccountItem?, for address: AccountAddress, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentMissingController(from: view, address: address, locale: locale)
        }, preservesCondition: { controller != nil })
    }

    func has(stash: AccountItem?, for address: AccountAddress, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentMissingStash(from: view, address: address, locale: locale)
        }, preservesCondition: { stash != nil })
    }

    func electionClosed(_ electionStatus: ElectionStatus?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentElectionPeriodIsNotClosed(from: view, locale: locale)
        }, preservesCondition: { electionStatus == .some(.close) })
    }

    func unbondingsLimitNotReached(_ count: Int?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnbondingLimitReached(from: view, locale: locale)
        }, preservesCondition: {
            if let count = count, count < SubstrateConstants.maxUnbondingRequests {
                return true
            } else {
                return false
            }
        })
    }

    func rewardIsHigherThanFee(
        reward: Decimal?,
        fee: Decimal?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentRewardIsLessThanFee(from: view, action: {
                delegate.didCompleteWarningHandling()
            }, locale: locale)
        }, preservesCondition: {
            if let reward = reward, let fee = fee {
                return reward > fee
            } else {
                return false
            }
        })
    }

    func controllerBalanceIsNotZero(_ balance: Decimal?, locale: Locale) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentControllerBalanceIsZero(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            if let balance = balance, balance > 0 {
                return true
            } else {
                return false
            }
        })
    }

    func stashIsNotKilledAfterUnbonding(
        amount: Decimal?,
        bonded: Decimal?,
        minimumAmount: Decimal?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentStashKilledAfterUnbond(from: view, action: {
                delegate.didCompleteWarningHandling()
            }, locale: locale)
        }, preservesCondition: {
            if let amount = amount, let bonded = bonded, let minimumAmount = minimumAmount {
                return bonded - amount >= minimumAmount
            } else {
                return false
            }
        })
    }

    func hasRedeemable(stakingLedger: StakingLedger?, in era: UInt32?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentNoRedeemables(from: view, locale: locale)
        }, preservesCondition: {
            if let era = era, let redeemable = stakingLedger?.redeemable(inEra: era), redeemable > 0 {
                return true
            } else {
                return false
            }
        })
    }

    func ledgerNotExist(
        stakingLedger: StakingLedger?,
        addressType _: SNAddressType,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentControllerIsAlreadyUsed(from: view, locale: locale)
        }, preservesCondition: {
            stakingLedger == nil
        })
    }

    func canNominate(
        amount: Decimal?,
        minimalBalance: Decimal?,
        minNominatorBond: Decimal?,
        locale: Locale
    ) -> DataValidating {
        let minAmount: Decimal? = {
            if let minimalBalance = minimalBalance, let minNominatorBond = minNominatorBond {
                return max(minimalBalance, minNominatorBond)
            }

            if let minNominatorBond = minNominatorBond {
                return minNominatorBond
            }

            return minimalBalance
        }()

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let amountString = minAmount.map {
                self?.balanceFactory?.amountFromValue($0).value(for: locale) ?? ""
            } ?? ""

            self?.presentable.presentAmountTooLow(value: amountString, from: view, locale: locale)
        }, preservesCondition: {
            guard let amount = amount else {
                return false
            }

            return minAmount.map { amount >= $0 } ?? true
        })
    }

    func maxNominatorsCountNotReached(
        counterForNominators: UInt32?,
        maxNominatorsCount: UInt32?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentMaxNumberOfNominatorsReached(from: view, locale: locale)
        }, preservesCondition: {
            if
                let counterForNominators = counterForNominators,
                let maxNominatorsCount = maxNominatorsCount {
                return counterForNominators < maxNominatorsCount
            } else {
                return true
            }
        })
    }
}
