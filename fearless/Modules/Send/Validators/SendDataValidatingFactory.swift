import Foundation
import SoraFoundation
import BigInt
import SSFModels

enum BalanceType {
    case utility(balance: Decimal?)
    case orml(balance: Decimal?, utilityBalance: Decimal?)
}

enum ExistentialDepositValidationParameters {
    case utility(spendingAmount: Decimal?, totalAmount: Decimal?, minimumBalance: Decimal?)
    case orml(minimumBalance: Decimal?, feeAndTip: Decimal?, utilityBalance: Decimal?)
    case equilibrium(minimumBalance: Decimal?, totalBalance: Decimal?)

    var minimumBalance: Decimal? {
        switch self {
        case let .utility(_, _, minimumBalance):
            return minimumBalance
        case let .orml(minimumBalance, _, _):
            return minimumBalance
        case let .equilibrium(minimumBalance, _):
            return minimumBalance
        }
    }
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

            let existentianDepositValue = "\(parameters.minimumBalance ?? .zero) \(chainAsset.asset.symbolUppercased)"

            if !canProceedIfViolated {
                self?.basePresentable.presentExistentialDepositError(
                    existentianDepositValue: existentianDepositValue,
                    from: view,
                    locale: locale
                )
            }

            self?.basePresentable.presentExistentialDepositWarning(
                existentianDepositValue: existentianDepositValue,
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )

        }, preservesCondition: {
            guard !chainAsset.chain.isEthereum else {
                return true
            }
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
                guard minimumBalance ?? 0 > 0 else {
                    return true
                }
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

    func soraBridgeViolated(
        originCHainId: ChainModel.Id,
        destChainId: ChainModel.Id?,
        amount: Decimal,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentSoraBridgeLowAmountError(
                from: view,
                locale: locale
            )
        }, preservesCondition: {
            guard let destChainId = destChainId else {
                return false
            }
            let originKnownChain = Chain(chainId: originCHainId)
            let destKnownChain = Chain(chainId: destChainId)

            switch (originKnownChain, destKnownChain) {
            case (.kusama, .soraMain):
                return amount >= 0.05
            default:
                return true
            }
        })
    }
}
