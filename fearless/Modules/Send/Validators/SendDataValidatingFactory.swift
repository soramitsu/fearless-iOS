import Foundation
import SoraFoundation
import BigInt

enum BalanceType {
    case utility(balance: Decimal?)
    case orml(balance: Decimal?, utilityBalance: Decimal?)
}

enum ExistentialDepositValidationParameters {
    case utility(spendingAmount: BigUInt?, totalAmount: BigUInt?, minimumBalance: BigUInt?)
    case orml(minimumBalance: Decimal?, feeAndTip: Decimal?, utilityBalance: Decimal?)
    case equilibrium(minimumBalance: Decimal?, totalBalance: Decimal?)
}

class SendDataValidatingFactory: NSObject {
    weak var view: (Localizable & ControllerBackedProtocol)?
    var basePresentable: BaseErrorPresentable

    init(
        presentable: BaseErrorPresentable
    ) {
        basePresentable = presentable
    }

    func canPayFeeAndAmount(
        balanceType: BalanceType,
        feeAndTip: Decimal?,
        sendAmount: Decimal?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentAmountTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            let amount = sendAmount ?? 0
            switch balanceType {
            case let .utility(balance):
                if let balance = balance,
                   let feeAndTip = feeAndTip {
                    return amount + feeAndTip <= balance
                } else {
                    return false
                }
            case let .orml(balance, utilityBalance):
                if let balance = balance,
                   let feeAndTip = feeAndTip,
                   let utilityBalance = utilityBalance {
                    return amount <= balance && feeAndTip <= utilityBalance
                } else {
                    return false
                }
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
        parameters: ExistentialDepositValidationParameters,
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
            switch parameters {
            case let .utility(spendingAmount, totalAmount, minimumBalance):
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
            case let .orml(minimumBalance, feeAndTip, utilityBalance):
                guard let feeAndTip = feeAndTip else {
                    return true
                }

                if let utilityBalance = utilityBalance, let minimumBalance = minimumBalance {
                    return utilityBalance - feeAndTip >= minimumBalance
                } else {
                    return false
                }
            case let .equilibrium(minimumBalance, totalBalance):
                guard let minimumBalance = minimumBalance,
                      let totalBalance = totalBalance
                else {
                    return false
                }

                return totalBalance > minimumBalance
            }
        })
    }
}
