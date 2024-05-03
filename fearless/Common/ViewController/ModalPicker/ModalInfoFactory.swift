import UIKit
import SoraFoundation
import SoraUI
import SSFModels

struct ModalInfoFactory {
    static let rowHeight: CGFloat = 50.0
    static let headerHeight: CGFloat = 40.0
    static let footerHeight: CGFloat = 0.0

    static func createRewardDetails(
        for maxReward: (title: String, amount: Decimal),
        avgReward: (title: String, amount: Decimal)
    ) -> UIViewController {
        let viewController: ModalPickerViewController<DetailsDisplayTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)
        viewController.cellHeight = Self.rowHeight
        viewController.headerHeight = Self.headerHeight
        viewController.footerHeight = Self.footerHeight
        viewController.allowsSelection = false
        viewController.hasCloseItem = false

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.stakingRewardInfoTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.detailsDisplayTableViewCell)
        viewController.modalPresentationStyle = .custom

        let formatter = NumberFormatter.percent.localizableResource()

        let maxViewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            let title = maxReward.title
            let details = formatter.value(for: locale).stringFromDecimal(maxReward.amount) ?? ""

            return TitleWithSubtitleViewModel(title: title, subtitle: details)
        }

        let avgViewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            let title = avgReward.title
            let details = formatter.value(for: locale).stringFromDecimal(avgReward.amount) ?? ""

            return TitleWithSubtitleViewModel(title: title, subtitle: details)
        }

        let viewModels = [maxViewModel, avgViewModel]
        viewController.viewModels = viewModels

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(viewModels.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createFromBalanceContext(
        _ balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<LocalizableDecimalFormatting>,
        precision: Int16,
        currency: Currency
    ) -> UIViewController {
        let viewController: ModalPickerViewController<BottomSheetInfoBalanceCell, StakingAmountViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)
        viewController.cellHeight = Self.rowHeight
        viewController.headerHeight = Self.headerHeight
        viewController.footerHeight = Self.footerHeight
        viewController.allowsSelection = false
        viewController.hasCloseItem = false
        viewController.separatorStyle = .singleLine
        viewController.separatorColor = R.color.colorDarkGray()

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.walletBalanceLocked(preferredLanguages: locale.rLanguages)
        }

        viewController.modalPresentationStyle = .custom

        let assetBalanceDisplayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let priceFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: assetBalanceDisplayInfo, usageCase: .fiat)

        let viewModels = createViewModelsForContext(
            balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
            precision: precision
        )

        viewController.viewModels = viewModels

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(viewModels.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    private static func createViewModelsForContext(
        _ balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<LocalizableDecimalFormatting>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        precision: Int16
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        print(balanceContext.toContext())
        let staticModels: [LocalizableResource<StakingAmountViewModel>] = [
            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletBalanceReserved(preferredLanguages: locale.rLanguages)

                let amountString = amountFormatter.value(for: locale).stringFromDecimal(balanceContext.reserved) ?? ""

                let formatter = priceFormatter.value(for: locale)

                let price = balanceContext.reserved * balanceContext.price
                let priceString = balanceContext.price == 0.0 ? nil : formatter.stringFromDecimal(price)

                let balance = BalanceViewModel(
                    amount: amountString,
                    price: priceString
                )

                return StakingAmountViewModel(title: title, balance: balance)
            }
        ]

        let balanceLockKnownModels: [LocalizableResource<StakingAmountViewModel>] =
            createLockViewModel(
                from: balanceContext.balanceLocks.mainLocks(),
                balanceContext: balanceContext,
                amountFormatter: amountFormatter,
                priceFormatter: priceFormatter,
                precision: precision
            )

        let balanceLockUnknownModels: [LocalizableResource<StakingAmountViewModel>] =
            createLockViewModel(
                from: balanceContext.balanceLocks.auxLocks(),
                balanceContext: balanceContext,
                amountFormatter: amountFormatter,
                priceFormatter: priceFormatter,
                precision: precision
            )

        return balanceLockKnownModels + balanceLockUnknownModels + staticModels
    }

    private static func createLockViewModel(
        from locks: BalanceLocks,
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<LocalizableDecimalFormatting>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        precision: Int16
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        locks.map { lock in
            LocalizableResource<StakingAmountViewModel> { locale in
                let formatter = priceFormatter.value(for: locale)
                let amountFormatter = amountFormatter.value(for: locale)

                let title: String = {
                    guard let mainTitle = LockType(rawValue: lock.displayId ?? "")?
                        .displayType
                        .value(for: locale) else {
                        return lock.displayId?.capitalized ?? ""
                    }
                    return mainTitle
                }()

                let lockAmount = Decimal.fromSubstrateAmount(
                    lock.amount,
                    precision: precision
                ) ?? 0.0
                let price = lockAmount * balanceContext.price

                let priceString = balanceContext.price == 0.0 ? nil : formatter.stringFromDecimal(price)
                let amountString = amountFormatter.stringFromDecimal(lockAmount) ?? ""

                let balance = BalanceViewModel(
                    amount: amountString,
                    price: priceString
                )

                return StakingAmountViewModel(
                    title: title, balance: balance
                )
            }
        }
    }
}
