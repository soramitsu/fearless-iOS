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
    private lazy var xcmAmountInspector: AppXcmMinAmountInspector = {
        AppXcmMinAmountInspectorImpl()
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
        warningPresentable: BaseErrorPresentable? = nil,
        proceedAction: @escaping () -> Void,
        setMaxAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] _ in
            guard let view = self?.view else {
                return
            }

            guard let presentable = warningPresentable ?? self?.basePresentable else { return }
            let symbol = chainAsset.chain.utilityAssets().first?.symbolUppercased ?? chainAsset.asset.symbolUppercased
            let existentianDepositValue = "\(minimumBalance) \(symbol)"

            if !canProceedIfViolated {
                presentable.presentExistentialDepositError(
                    existentianDepositValue: existentianDepositValue,
                    from: view,
                    locale: locale
                )
            }
            presentable.presentExistentialDepositWarning(
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

    /// The reviewed minimum of the exact origin asset and direction, in its base units. An unknown minimum or an
    /// unreviewed route stops the transfer instead of passing unchecked.
    func reviewedBridgeMinimumIsNotViolated(
        amount: BigUInt?,
        origin: ChainAsset,
        destination: ChainModel?,
        locale: Locale
    ) -> DataValidating {
        var failure: AppXcmMinAmountError = .ruleUnavailable
        return ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view = self.view else {
                return
            }

            switch failure {
            case let .minAmountError(minimum):
                self.basePresentable.presentSoraBridgeLowAmountError(
                    from: view,
                    locale: locale,
                    assetAmount: minimum
                )
            case .ruleUnavailable:
                (self.basePresentable as? SheetAlertPresentable)?.present(
                    message: NSLocalizedString(
                        "cross_chain.minimum_unavailable",
                        value: "The reviewed minimum for this exact asset and direction is unavailable, so the transfer was not prepared.",
                        comment: ""
                    ),
                    title: R.string.localizable.commonWarning(preferredLanguages: locale.rLanguages),
                    closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                    from: view,
                    actions: []
                )
            }
        }, preservesCondition: { [weak self] in
            guard let self, let amount, let destination else {
                failure = .ruleUnavailable
                return false
            }
            do {
                try self.xcmAmountInspector.inspectMin(amount: amount, origin: origin, destination: destination)
                return true
            } catch let error as AppXcmMinAmountError {
                failure = error
                return false
            } catch {
                failure = .ruleUnavailable
                return false
            }
        })
    }
}
