import Foundation
import SoraFoundation
import BigInt

protocol BaseDataValidatingFactoryProtocol: AnyObject {
    var view: (ControllerBackedProtocol & Localizable)? { get }
    var basePresentable: BaseErrorPresentable { get }

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

    func has(fee: Decimal?, locale: Locale, onError: (() -> Void)?) -> DataValidating

    func exsitentialDepositIsNotViolated(
        spendingAmount: BigUInt?,
        totalAmount: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale,
        chainAsset: ChainAsset,
        canProceedIfViolated: Bool
    ) -> DataValidating
}

extension BaseDataValidatingFactoryProtocol {
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

            self?.basePresentable.presentAmountTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            let amount = spendingAmount ?? 0

            if let balance = balance,
               let fee = fee {
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

            self?.basePresentable.presentFeeTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            if let balance = balance,
               let fee = fee {
                return fee <= balance
            } else {
                return false
            }
        })
    }

    func has(fee: Decimal?, locale: Locale, onError: (() -> Void)?) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            defer {
                onError?()
            }

            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentFeeNotReceived(from: view, locale: locale)
        }, preservesCondition: { fee != nil })
    }

    func exsitentialDepositIsNotViolated(
        spendingAmount: BigUInt?,
        totalAmount: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale,
        chainAsset: ChainAsset,
        canProceedIfViolated: Bool = true
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            if !canProceedIfViolated {
                self?.basePresentable.presentExistentialDepositError(from: view, locale: locale)
            }

            self?.basePresentable.presentExistentialDepositWarning(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )

        }, preservesCondition: {
            guard let spendingAmount = spendingAmount else {
                return true
            }

            if case .ormlChain = chainAsset.chainAssetType {
                return true
            }

            if
                let totalAmount = totalAmount,
                let minimumBalance = minimumBalance,
                totalAmount >= spendingAmount {
                return totalAmount - spendingAmount >= minimumBalance
            } else {
                return false
            }
        })
    }
}
