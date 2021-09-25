import Foundation
import SoraFoundation
import BigInt
import CommonWallet

protocol CrowdloanDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func contributesAtLeastMinContribution(
        contribution: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func capNotExceeding(
        contribution: BigUInt?,
        raised: BigUInt?,
        cap: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func crowdloanIsNotCompleted(
        crowdloan: Crowdloan?,
        metadata: CrowdloanMetadata?,
        locale: Locale
    ) -> DataValidating

    func crowdloanIsNotPrivate(
        crowdloan: Crowdloan?,
        locale: Locale
    ) -> DataValidating
}

final class CrowdloanDataValidatingFactory: CrowdloanDataValidatorFactoryProtocol {
    weak var view: (ControllerBackedProtocol & Localizable)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: CrowdloanErrorPresentable
    let assetInfo: AssetBalanceDisplayInfo
    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        presentable: CrowdloanErrorPresentable,
        assetInfo: AssetBalanceDisplayInfo,
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.presentable = presentable
        self.assetInfo = assetInfo
        self.amountFormatterFactory = amountFormatterFactory
    }

    func contributesAtLeastMinContribution(
        contribution: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let strongSelf = self, let view = strongSelf.view else {
                return
            }

            let formatter = strongSelf.amountFormatterFactory.createDisplayFormatter(
                for: strongSelf.assetInfo
            ).value(for: locale)

            let minimumBalanceString = minimumBalance
                .map { Decimal.fromSubstrateAmount($0, precision: strongSelf.assetInfo.assetPrecision) }?
                .map { formatter.stringFromDecimal($0) } ?? nil

            self?.presentable.presentMinimalBalanceContributionError(
                minimumBalanceString ?? "",
                from: view,
                locale: locale
            )

        }, preservesCondition: {
            if let contribution = contribution,
               let minimumBalance = minimumBalance {
                return contribution >= minimumBalance
            } else {
                return false
            }
        })
    }

    func capNotExceeding(
        contribution: BigUInt?,
        raised: BigUInt?,
        cap: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let strongSelf = self, let view = strongSelf.view else {
                return
            }

            if let raised = raised,
               let cap = cap,
               cap > raised {
                let decimalDiff = Decimal.fromSubstrateAmount(
                    cap - raised,
                    precision: strongSelf.assetInfo.assetPrecision
                )

                let diffString = decimalDiff.map {
                    strongSelf.amountFormatterFactory.createDisplayFormatter(for: strongSelf.assetInfo)
                        .value(for: locale)
                        .stringFromDecimal($0)
                } ?? nil

                self?.presentable.presentAmountExceedsCapError(diffString ?? "", from: view, locale: locale)

            } else {
                self?.presentable.presentCapReachedError(from: view, locale: locale)
            }

        }, preservesCondition: {
            if let contribution = contribution,
               let raised = raised,
               let cap = cap {
                return raised + contribution <= cap
            } else {
                return false
            }
        })
    }

    func crowdloanIsNotCompleted(
        crowdloan: Crowdloan?,
        metadata: CrowdloanMetadata?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCrowdloanEnded(from: view, locale: locale)

        }, preservesCondition: {
            if let crowdloan = crowdloan,
               let metadata = metadata {
                return !crowdloan.isCompleted(for: metadata)
            } else {
                return false
            }
        })
    }

    func crowdloanIsNotPrivate(
        crowdloan: Crowdloan?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCrowdloanPrivateNotSupported(from: view, locale: locale)

        }, preservesCondition: {
            crowdloan?.fundInfo.verifier == nil
        })
    }
}
