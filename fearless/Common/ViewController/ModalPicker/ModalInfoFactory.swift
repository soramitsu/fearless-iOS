import UIKit
import SoraFoundation
import SoraUI
import CommonWallet

struct ModalInfoFactory {
    static let rowHeight: CGFloat = 50.0
    static let headerHeight: CGFloat = 40.0
    static let footerHeight: CGFloat = 0.0

    static func createFromBalanceContext(_ balanceContext: BalanceContext,
                                         amountFormatter: LocalizableResource<NumberFormatter>)
        -> UIViewController {

        let viewController: ModalPickerViewController<DetailsDisplayTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)
        viewController.cellHeight = Self.rowHeight
        viewController.headerHeight = Self.headerHeight
        viewController.footerHeight = Self.footerHeight
        viewController.allowsSelection = false
        viewController.hasCloseItem = true

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.walletBalanceFrozen(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.detailsDisplayTableViewCell)
        viewController.modalPresentationStyle = .custom

        let viewModels = createViewModelsForContext(balanceContext,
                                                    amountFormatter: amountFormatter)
        viewController.viewModels = viewModels

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(viewModels.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createTransferExistentialState(_ state: TransferExistentialState,
                                               amountFormatter: LocalizableResource<NumberFormatter>)
        -> UIViewController {
        let viewController: ModalPickerViewController<DetailsDisplayTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)
        viewController.cellHeight = Self.rowHeight
        viewController.headerHeight = Self.headerHeight
        viewController.footerHeight = Self.footerHeight
        viewController.allowsSelection = false
        viewController.hasCloseItem = true

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.walletSendBalanceDetails(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.detailsDisplayTableViewCell)
        viewController.modalPresentationStyle = .custom

        let viewModels = createTransferStateViewModels(state,
                                                       amountFormatter: amountFormatter)
        viewController.viewModels = viewModels

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(viewModels.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    private static func createTransferStateViewModels(_ state: TransferExistentialState,
                                                      amountFormatter: LocalizableResource<NumberFormatter>)
        -> [LocalizableResource<TitleWithSubtitleViewModel>] {
        [
            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletSendAvailableBalance(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: state.availableAmount as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            },

            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletSendBalanceTotal(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: state.totalAmount as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            },

            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletSendBalanceTotalAfterTransfer(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: state.totalAfterTransfer as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            },

            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletSendBalanceExistential(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: state.existentialDeposit as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            }
        ]
    }

    private static func createViewModelsForContext(_ balanceContext: BalanceContext,
                                                   amountFormatter: LocalizableResource<NumberFormatter>)
        -> [LocalizableResource<TitleWithSubtitleViewModel>] {
        [
            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletBalanceLocked(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: balanceContext.locked as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            },

            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletBalanceBonded(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: balanceContext.bonded as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            },

            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletBalanceReserved(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: balanceContext.reserved as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            },

            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletBalanceRedeemable(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: balanceContext.redeemable as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            },

            LocalizableResource { locale in
                let title = R.string.localizable
                    .walletBalanceUnbonding(preferredLanguages: locale.rLanguages)
                let details = amountFormatter.value(for: locale)
                    .string(from: balanceContext.unbonding as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title, subtitle: details)
            }
        ]
    }
}
