import Foundation
import SoraFoundation

protocol StakingDataValidatingFactoryProtocol {
    func canPayFeeAndAmount(
        balance: Decimal?,
        fee: Decimal?,
        spendingAmount: Decimal?,
        locale: Locale
    ) -> DataValidating

    func canPayFee(
        balance: Decimal?,
        fee: Decimal?,
        locale: Locale
    ) -> DataValidating

    func canUnbond(amount: Decimal?, bonded: Decimal?, locale: Locale) -> DataValidating

    func has(controller: AccountItem?, for address: AccountAddress, locale: Locale) -> DataValidating
    func has(fee: Decimal?, locale: Locale, onError: (() -> Void)?) -> DataValidating
    func electionClosed(_ electionStatus: ElectionStatus?, locale: Locale) -> DataValidating
    func unbondingsLimitNotReached(_ count: Int?, locale: Locale) -> DataValidating

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
}

final class StakingDataValidatingFactory: StakingDataValidatingFactoryProtocol {
    weak var view: (ControllerBackedProtocol & Localizable)?
    let presentable: StakingErrorPresentable

    init(presentable: StakingErrorPresentable) {
        self.presentable = presentable
    }

    func canPayFeeAndAmount(
        balance: Decimal?,
        fee: Decimal?,
        spendingAmount: Decimal?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentAmountTooHigh(from: view, locale: locale)

        }, checkCondition: {
            if let balance = balance,
               let fee = fee,
               let amount = spendingAmount {
                return amount + fee <= balance
            } else {
                return false
            }
        })
    }

    func canPayFee(
        balance: Decimal?,
        fee: Decimal?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentFeeTooHigh(from: view, locale: locale)

        }, checkCondition: {
            if let balance = balance,
               let fee = fee {
                return fee <= balance
            } else {
                return false
            }
        })
    }

    func canUnbond(amount: Decimal?, bonded: Decimal?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnbondingTooHigh(from: view, locale: locale)

        }, checkCondition: {
            if let amount = amount,
               let bonded = bonded {
                return amount <= bonded
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
        }, checkCondition: { controller != nil })
    }

    func has(fee: Decimal?, locale: Locale, onError: (() -> Void)?) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            defer {
                onError?()
            }

            guard let view = self?.view else {
                return
            }

            self?.presentable.presentFeeNotReceived(from: view, locale: locale)
        }, checkCondition: { fee != nil })
    }

    func electionClosed(_ electionStatus: ElectionStatus?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentElectionPeriodIsNotClosed(from: view, locale: locale)
        }, checkCondition: { electionStatus == .some(.close) })
    }

    func unbondingsLimitNotReached(_ count: Int?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnbondingLimitReached(from: view, locale: locale)
        }, checkCondition: {
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
        }, checkCondition: {
            if let reward = reward, let fee = fee {
                return reward > fee
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
        }, checkCondition: {
            if let amount = amount, let bonded = bonded, let minimumAmount = minimumAmount {
                return bonded - amount >= minimumAmount
            } else {
                return false
            }
        })
    }
}
