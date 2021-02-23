import Foundation
import SoraUI
import SoraFoundation
import IrohaCrypto
import FearlessUtils

enum AccountHeaderType {
    case title(_ title: LocalizableResource<String>)
    case address(_ type: SNAddressType, title: LocalizableResource<String>)
}

struct ModalPickerFactory {
    static func createPickerForList(_ types: [CryptoType],
                                    selectedType: CryptoType?,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?) -> UIViewController? {
        guard types.count > 0 else {
            return nil
        }

        let viewController: ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.commonCryptoType(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.titleWithSubtitleTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        if let selectedType = selectedType {
            viewController.selectedIndex = types.firstIndex(of: selectedType) ?? 0
        } else {
            viewController.selectedIndex = 0
        }

        viewController.viewModels = types.map { type in
            LocalizableResource { locale in
                TitleWithSubtitleViewModel(title: type.titleForLocale(locale),
                                           subtitle: type.subtitleForLocale(locale))
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(types.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(_ types: [Chain],
                                    selectedType: Chain?,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?) -> UIViewController? {
        guard types.count > 0 else {
            return nil
        }

        let viewController: ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.commonChooseNetwork(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.iconWithTitleTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        if let selectedType = selectedType {
            viewController.selectedIndex = types.firstIndex(of: selectedType) ?? 0
        } else {
            viewController.selectedIndex = 0
        }

        viewController.viewModels = types.map { type in
            LocalizableResource { locale in
                IconWithTitleViewModel(icon: type.icon,
                                       title: type.titleForLocale(locale))
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(types.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(_ types: [AccountImportSource],
                                    selectedType: AccountImportSource?,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?) -> UIViewController? {
        guard types.count > 0 else {
            return nil
        }

        let viewController: ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.importSourcePickerTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.titleWithSubtitleTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        if let selectedType = selectedType {
            viewController.selectedIndex = types.firstIndex(of: selectedType) ?? 0
        } else {
            viewController.selectedIndex = 0
        }

        viewController.viewModels = types.map { type in
            LocalizableResource { locale in
                TitleWithSubtitleViewModel(title: type.titleForLocale(locale),
                                           subtitle: "")
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(types.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerList(_ accounts: [AccountItem],
                                 selectedAccount: AccountItem?,
                                 title: LocalizableResource<String>,
                                 delegate: ModalPickerViewControllerDelegate?,
                                 context: AnyObject?) -> UIViewController? {

        createPickerList(accounts,
                         selectedAccount: selectedAccount,
                         headerType: .title(title),
                         delegate: delegate,
                         context: context)
    }

    static func createPickerList(_ accounts: [AccountItem],
                                 selectedAccount: AccountItem?,
                                 addressType: SNAddressType,
                                 delegate: ModalPickerViewControllerDelegate?,
                                 context: AnyObject?) -> UIViewController? {

        let localizedTitle = LocalizableResource { locale in
            R.string.localizable.profileAccountsTitle(preferredLanguages: locale.rLanguages)
        }

        return createPickerList(accounts,
                                selectedAccount: selectedAccount,
                                headerType: .address(addressType, title: localizedTitle),
                                delegate: delegate,
                                context: context)
    }

    static func createPickerList(_ accounts: [AccountItem],
                                 selectedAccount: AccountItem?,
                                 headerType: AccountHeaderType,
                                 delegate: ModalPickerViewControllerDelegate?,
                                 context: AnyObject?) -> UIViewController? {

        let viewController: ModalPickerViewController<AccountPickerTableViewCell, AccountPickerViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        switch headerType {
        case .title(let title):
            viewController.localizedTitle = title
        case .address(let type, let title):
            viewController.localizedTitle = title
            viewController.icon = type.icon
            viewController.actionType = .add
        }

        viewController.cellNib = UINib(resource: R.nib.accountPickerTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        if let selectedAccount = selectedAccount {
            viewController.selectedIndex = accounts.firstIndex(of: selectedAccount) ?? NSNotFound
        } else {
            viewController.selectedIndex = NSNotFound
        }

        let iconGenerator = PolkadotIconGenerator()

        viewController.viewModels = accounts.compactMap { account in
            let viewModel: AccountPickerViewModel
            if let icon = try? iconGenerator.generateFromAddress(account.address) {
                viewModel = AccountPickerViewModel(title: account.username, icon: icon)
            } else {
                viewModel = AccountPickerViewModel(title: account.username, icon: EmptyAccountIcon())
            }

            return LocalizableResource { _ in viewModel }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(accounts.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}
