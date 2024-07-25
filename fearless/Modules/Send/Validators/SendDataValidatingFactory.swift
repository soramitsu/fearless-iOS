import Foundation
import SSFXCM
import SoraFoundation
import BigInt
import SSFModels

enum BalanceType {
    case utility(balance: Decimal?)
    case orml(balance: Decimal?, utilityBalance: Decimal?)
}

class SendDataValidatingFactory: NSObject {
    private lazy var xcmAmountInspector: XcmMinAmountInspector = {
        XcmMinAmountInspectorImpl()
    }()

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
        spending: Decimal,
        balance: Decimal,
        minimumBalance: Decimal,
        chainAsset: ChainAsset,
        locale: Locale,
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
            let existentianDepositValue = "\(minimumBalance) \(symbol)"

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
            return balance - spending >= minimumBalance
        })
    }

    func destinationExistentialDepositIsNotViolated(
        willReceived: Decimal,
        minimumBalance: Decimal,
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

            return willReceived >= minimumBalance
        })
    }

    func soraBridgeViolated(
        originCHain: ChainModel,
        destChain: ChainModel?,
        amount: Decimal,
        locale: Locale,
        asset: AssetModel
    ) -> DataValidating {
        ErrorThrowingViolation(onError: { [weak self] errorText in
            guard let self, let view = self.view else {
                return
            }

            self.basePresentable.presentSoraBridgeLowAmountError(
                from: view,
                locale: locale,
                assetAmount: errorText
            )
        }, preservesCondition: { [weak self] in
            guard
                let self,
                let destChain,
                let substrateAmount = amount.toSubstrateAmount(precision: Int16(asset.precision))
            else {
                return nil
            }
            do {
                try self.xcmAmountInspector.inspectMin(
                    amount: substrateAmount,
                    fromChainModel: originCHain,
                    destChainModel: destChain,
                    assetSymbol: asset.symbol
                )
                return nil
            } catch {
                guard let xcmError = error as? XcmError, case let .minAmountError(minAmount) = xcmError else {
                    return nil
                }
                return minAmount
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
