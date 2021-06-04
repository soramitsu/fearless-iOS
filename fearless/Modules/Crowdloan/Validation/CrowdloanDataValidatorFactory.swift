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
}

final class CrowdloanDataValidatingFactory: CrowdloanDataValidatorFactoryProtocol {
    weak var view: (ControllerBackedProtocol & Localizable)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: CrowdloanErrorPresentable
    let chain: Chain
    let asset: WalletAsset
    let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(
        presentable: CrowdloanErrorPresentable,
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        chain: Chain,
        asset: WalletAsset
    ) {
        self.presentable = presentable
        self.amountFormatterFactory = amountFormatterFactory
        self.chain = chain
        self.asset = asset
    }

    func contributesAtLeastMinContribution(
        contribution: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard
                let view = self?.view,
                let formatter = self?.amountFormatterFactory
                .createDisplayFormatter(for: self?.asset).value(for: locale),
                let precision = self?.chain.addressType.precision else {
                return
            }

            let minimumBalanceString = minimumBalance
                .map { Decimal.fromSubstrateAmount($0, precision: precision) }?
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
                    precision: strongSelf.chain.addressType.precision
                )

                let diffString = decimalDiff.map {
                    strongSelf.amountFormatterFactory.createDisplayFormatter(
                        for: strongSelf.asset
                    )
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
}
