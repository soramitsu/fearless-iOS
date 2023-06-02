import Foundation
import SoraUI
import SoraFoundation
import IrohaCrypto
import SSFUtils

enum AccountHeaderType {
    case title(_ title: LocalizableResource<String>)
    case address(_ type: SNAddressType, title: LocalizableResource<String>)
}

// swiftlint:disable type_body_length
enum ModalPickerFactory {
    static func createPickerForList(
        _ types: [CryptoType],
        selectedType: CryptoType?,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !types.isEmpty else {
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
                TitleWithSubtitleViewModel(
                    title: type.titleForLocale(locale),
                    subtitle: type.subtitleForLocale(locale)
                )
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

    static func createPickerForList(
        _ types: [AccountImportSource],
        selectedType: AccountImportSource?,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !types.isEmpty else {
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
                TitleWithSubtitleViewModel(
                    title: type.titleForLocale(locale),
                    subtitle: ""
                )
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

    static func createPickerList(
        _ accounts: [ChainAccountResponse],
        selectedAccount: ChainAccountResponse?,
        title: LocalizableResource<String>,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        createPickerList(
            accounts,
            selectedAccount: selectedAccount,
            headerType: .title(title),
            delegate: delegate,
            context: context
        )
    }

    static func createPickerList(
        _ accounts: [ChainAccountResponse],
        selectedAccount: ChainAccountResponse?,
        addressType: SNAddressType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let localizedTitle = LocalizableResource { locale in
            R.string.localizable.profileAccountsTitle(preferredLanguages: locale.rLanguages)
        }

        return createPickerList(
            accounts,
            selectedAccount: selectedAccount,
            headerType: .address(addressType, title: localizedTitle),
            delegate: delegate,
            context: context
        )
    }

    static func createPickerList(
        _ accounts: [ChainAccountResponse],
        selectedAccount: ChainAccountResponse?,
        headerType: AccountHeaderType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<AccountPickerTableViewCell, AccountPickerViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        switch headerType {
        case let .title(title):
            viewController.localizedTitle = title
        case let .address(type, title):
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
            if let icon = try? iconGenerator.generateFromAddress(account.toAddress() ?? "") {
                viewModel = AccountPickerViewModel(title: account.name, icon: icon)
            } else {
                viewModel = AccountPickerViewModel(title: account.name, icon: EmptyAccountIcon())
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

    static func createPickerForList(
        _ items: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<StakingManageCell, StakingManageViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.stakingManageTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.selectedIndex = NSNotFound
        viewController.separatorStyle = .singleLine
        viewController.cellHeight = StakingManageCell.cellHeight

        viewController.viewModels = items.map { type in
            LocalizableResource { locale in
                StakingManageViewModel(
                    icon: type.icon,
                    title: type.titleForLocale(locale),
                    details: type.detailsForLocale(locale)
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight
            + CGFloat(items.count) * viewController.cellHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        _ items: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<PurchaseProviderPickerTableViewCell, IconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.walletAssetBuy(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.purchaseProviderPickerTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.selectedIndex = NSNotFound

        viewController.viewModels = items.map { type in
            LocalizableResource { _ in
                IconWithTitleViewModel(
                    icon: type.icon,
                    title: type.title
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        _ items: [LocalizableResource<StakingAmountViewModel>],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<BottomSheetInfoBalanceCell, StakingAmountViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)
        }

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.selectedIndex = NSNotFound
        viewController.separatorStyle = .singleLine
        viewController.separatorColor = R.color.colorDarkGray()

        viewController.viewModels = items

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        title: String,
        _ chainActions: [ChainAction],
        callback: ModalPickerSelectionCallback?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !chainActions.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { _ in title }
        viewController.showSelection = false
        viewController.cellNib = UINib(resource: R.nib.iconWithTitleTableViewCell)
        viewController.selectionCallback = callback
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        viewController.viewModels = chainActions.map { action in
            LocalizableResource { locale in
                IconWithTitleViewModel(
                    icon: action.icon,
                    title: action.localizableTitle(for: locale)
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(chainActions.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        _ chainActions: [JsonExportAction],
        callback: ModalPickerSelectionCallback?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !chainActions.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.importSourcePickerTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.showSelection = false
        viewController.cellNib = UINib(resource: R.nib.titleWithSubtitleTableViewCell)
        viewController.selectionCallback = callback
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        viewController.viewModels = chainActions.map { action in
            LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: action.localizableTitle(for: locale),
                    subtitle: ""
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(chainActions.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForWalletActions(
        _ items: [WalletSettingsRow],
        callback: ModalPickerSelectionCallback?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.walletSettings(preferredLanguages: locale.rLanguages)
        }

        viewController.showSelection = false
        viewController.cellNib = UINib(resource: R.nib.iconWithTitleTableViewCell)
        viewController.selectionCallback = callback
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.separatorStyle = .singleLine
        viewController.separatorColor = R.color.colorLightGray()
        viewController.separatorInset = UIEdgeInsets(
            top: 0,
            left: UIConstants.bigOffset,
            bottom: 0,
            right: UIConstants.bigOffset
        )

        viewController.viewModels = items.map { item in
            LocalizableResource { _ in
                IconWithTitleViewModel(
                    icon: item.row.icon,
                    title: item.row.title
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        _ chainActions: [ReplaceChainOption],
        callback: ModalPickerSelectionCallback?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !chainActions.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.replaceAccount(preferredLanguages: locale.rLanguages)
        }

        viewController.showSelection = false
        viewController.cellNib = UINib(resource: R.nib.iconWithTitleTableViewCell)
        viewController.selectionCallback = callback
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        viewController.viewModels = chainActions.map { action in
            LocalizableResource { locale in
                IconWithTitleViewModel(
                    icon: action.icon,
                    title: action.localizableTitle(for: locale)
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(chainActions.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForSelectCurrency(
        supportedCurrencys: [Currency],
        selectedCurrency: Currency,
        callback: ModalPickerSelectionCallback?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.commonCurrency(preferredLanguages: locale.rLanguages)
        }

        viewController.showSelection = true
        viewController.cellNib = UINib(resource: R.nib.iconWithTitleTableViewCell)
        viewController.selectionCallback = callback
        viewController.modalPresentationStyle = .custom
        viewController.selectedIndex = supportedCurrencys.firstIndex(where: { $0.id == selectedCurrency.id }) ?? 0
        viewController.presenterCanDrag = false

        viewController.viewModels = supportedCurrencys.map { action in
            LocalizableResource { _ in
                var remoteImageViewModel: RemoteImageViewModel?
                if let iconUrl = URL(string: action.icon) {
                    remoteImageViewModel = RemoteImageViewModel(url: iconUrl)
                }
                return IconWithTitleViewModel(
                    icon: nil,
                    remoteImageViewModel: remoteImageViewModel,
                    title: action.id.uppercased()
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = UIScreen.main.bounds.height / 3
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForFilterOptions(
        options: [TitleSwitchTableViewCellModel]
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<TitleSwitchTableViewCell, TitleSwitchTableViewCellModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.walletFiltersTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.showSelection = false
        viewController.hideWhenDidSelected = false
        viewController.modalPresentationStyle = .custom

        viewController.viewModels = options.map { model in
            LocalizableResource { _ in
                model
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(options.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForSortOptions(
        options: [SortPickerTableViewCellModel],
        callback: ModalPickerSelectionCallback?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<SortPickerTableViewCell, SortPickerTableViewCellModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.commonFilterSortHeader(preferredLanguages: locale.rLanguages)
        }

        viewController.showSelection = false
        viewController.hideWhenDidSelected = true
        viewController.modalPresentationStyle = .custom
        viewController.headerBorderType = .none
        viewController.selectionCallback = callback

        viewController.viewModels = options.map { model in
            LocalizableResource { _ in
                model
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(options.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPicker(viewModels: [TitleWithSubtitleViewModel], callback: ModalPickerSelectionCallback?) -> UIViewController? {
        let viewController: ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.optionsCommon(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.titleWithSubtitleTableViewCell)
        viewController.showSelection = false
        viewController.hideWhenDidSelected = true
        viewController.modalPresentationStyle = .custom
        viewController.headerBorderType = .none
        viewController.selectionCallback = callback

        viewController.viewModels = viewModels.map { model in
            LocalizableResource { _ in
                model
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(viewModels.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}
