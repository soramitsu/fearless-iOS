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
        canProceedIfViolated: Bool = true,
        sendAllEnabled: Bool = false,
        proceedAction: @escaping () -> Void,
        setMaxAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] _ in
            guard let view = self?.view else {
                return
            }

            let symbol = chainAsset.chain.utilityAssets().first?.symbolUppercased ?? chainAsset.asset.symbolUppercased
            let existentianDepositValue = "\(parameters.minimumBalance ?? .zero) \(symbol)"

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
                proceedHandler: proceedAction,
                setMaxHandler: setMaxAction,
                cancelHandler: cancelAction,
                locale: locale
            )
        }, preservesCondition: {
            guard !chainAsset.chain.isEthereum else {
                return true
            }
            if sendAllEnabled, canProceedIfViolated {
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

    func destinationExistentialDepositIsNotViolated(
        parameters: ExistentialDepositValidationParameters,
        locale: Locale,
        chainAsset: ChainAsset
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] _ in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentDestinationExistentialDepositError(from: view, locale: locale)

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
        locale: Locale,
        asset: AssetModel
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view = self.view, let destChainId else {
                return
            }

            let assetAmount = self.minAssetAmount(originCHainId: originCHainId, destChainId: destChainId)

            self.basePresentable.presentSoraBridgeLowAmountError(
                from: view,
                originChainId: originCHainId,
                locale: locale,
                assetAmount: assetAmount
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
            case (.polkadot, .soraMain), (.soraMain, .polkadot):
                return amount >= 1.1
            case (.liberland, .soraMain):
                guard asset.symbol.lowercased() == "lld" else {
                    return true
                }
                return amount >= 1.0
            case (.soraMain, .liberland):
                guard asset.symbol.lowercased() == "lld" else {
                    return true
                }
                return amount >= 1.0
            case (.soraMain, .acala):
                return amount >= 1.0
            case (.acala, .soraMain):
                return amount >= 56.0
            default:
                return true
            }
        })
    }

    func soraBridgeAmountLessFeeViolated(
        originCHainId: ChainModel.Id,
        destChainId: ChainModel.Id?,
        amount: Decimal,
        fee: Decimal?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation { [weak self] delegate in
            guard let view = self?.view else {
                return
            }
            let title = R.string.localizable.commonWarning(preferredLanguages: locale.rLanguages)
            let originKnownChain = Chain(chainId: originCHainId)?.rawValue ?? ""
            let message = R.string.localizable.soraBridgeAmountLessFee(originKnownChain, preferredLanguages: locale.rLanguages)
            self?.basePresentable.presentWarning(
                for: title,
                message: message,
                action: { delegate.didCompleteWarningHandling() },
                view: view,
                locale: locale
            )
        } preservesCondition: {
            guard let destChainId = destChainId, let fee = fee else {
                return false
            }
            let originKnownChain = Chain(chainId: originCHainId)
            let destKnownChain = Chain(chainId: destChainId)

            switch (originKnownChain, destKnownChain) {
            case (.soraMain, .kusama):
                return amount > fee
            case (.soraMain, .polkadot):
                return amount > fee
            default:
                return true
            }
        }
    }

    private func minAssetAmount(
        originCHainId: ChainModel.Id,
        destChainId: ChainModel.Id
    ) -> String {
        let originKnownChain = Chain(chainId: originCHainId)
        let destKnownChain = Chain(chainId: destChainId)

        switch (originKnownChain, destKnownChain) {
        case (.kusama, .soraMain):
            return "0.05 KSM"
        case (.polkadot, .soraMain), (.soraMain, .polkadot):
            return "1.1 DOT"
        case (.liberland, .soraMain):
            return "1.0 LLD"
        case (.soraMain, .liberland):
            return "1.0 LLD"
        case (.soraMain, .acala):
            return "1.0 ACA"
        case (.acala, .soraMain):
            return "56.0 ACA"
        default:
            return ""
        }
    }
}
