import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit

protocol ProfileViewModelFactoryProtocol: AnyObject {
    func createProfileViewModel(
        from wallet: MetaAccountModel,
        locale: Locale,
        language: Language,
        currency: Currency,
        balance: WalletBalanceInfo?,
        missingAccountIssue: [ChainIssue]
    ) -> ProfileViewModelProtocol
}

enum ProfileOption: UInt, CaseIterable {
    case walletConnect
    case accountList
    case currency
    case language
    case polkaswapDisclaimer
    case changePincode
    case biometry
    case about
    case accountScore
    case networkAssets
    case tonConnect
    case irohaConnect
    case previousData
    case emergencyMaterial
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {
    // MARK: - Private properties

    private let iconGenerator: IconGenerating
    private let biometry: BiometryAuthProtocol
    private let settings: SettingsManagerProtocol
    private lazy var assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
    private let accountScoreFetcher: AccountStatisticsFetching
    private let irohaConnectPolicy: IrohaConnectReleasePolicy

    // MARK: - Constructors

    init(
        iconGenerator: IconGenerating,
        biometry: BiometryAuthProtocol,
        settings: SettingsManagerProtocol,
        accountScoreFetcher: AccountStatisticsFetching,
        irohaConnectPolicy: IrohaConnectReleasePolicy = .production
    ) {
        self.iconGenerator = iconGenerator
        self.biometry = biometry
        self.settings = settings
        self.accountScoreFetcher = accountScoreFetcher
        self.irohaConnectPolicy = irohaConnectPolicy
    }

    // MARK: - Public methods

    func createProfileViewModel(
        from wallet: MetaAccountModel,
        locale: Locale,
        language: Language,
        currency: Currency,
        balance: WalletBalanceInfo?,
        missingAccountIssue: [ChainIssue]
    ) -> ProfileViewModelProtocol {
        let profileUserViewModel = createUserViewModel(
            from: wallet,
            balance: balance,
            locale: locale
        )
        let profileOptionViewModel = createOptionViewModels(
            wallet: wallet,
            language: language,
            currency: currency,
            locale: locale,
            missingAccountIssue: missingAccountIssue
        )
        let logoutViewModel = createLogoutViewModel(locale: locale)
        return ProfileViewModel(
            profileUserViewModel: profileUserViewModel,
            profileOptionViewModel: profileOptionViewModel,
            logoutViewModel: logoutViewModel
        )
    }

    // MARK: - Private methods

    private func tokenFormatter(for currency: Currency, locale: Locale) -> TokenFormatter {
        let balanceDisplayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let balanceTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: balanceDisplayInfo, usageCase: .detailsCrypto)
        return balanceTokenFormatter.value(for: locale)
    }

    private func createUserViewModel(
        from wallet: MetaAccountModel,
        balance: WalletBalanceInfo?,
        locale: Locale
    ) -> WalletsManagmentCellViewModel {
        var fiatBalance = ""
        var dayChange: NSAttributedString?
        if let balance = balance {
            let formatter = tokenFormatter(for: balance.currency, locale: locale)
            fiatBalance = formatter.stringFromDecimal(balance.totalFiatValue) ?? ""
            dayChange = getDayChangeAttributedString(
                currency: balance.currency,
                dayChange: balance.totalDayChangePercent,
                dayChangeValue: balance.totalDayChangeValue,
                locale: locale
            )
        }

        let address = wallet.ethereumAddress?.toHex(includePrefix: true)
        let accountScoreViewModel = AccountScoreViewModel(fetcher: accountScoreFetcher, address: address, chain: nil, settings: settings, eventCenter: EventCenter.shared, logger: Logger.shared)

        return WalletsManagmentCellViewModel(
            isSelected: false,
            walletName: wallet.name,
            fiatBalance: fiatBalance,
            dayChange: dayChange,
            accountScoreViewModel: accountScoreViewModel,
            balanceCaption: balance?.allHoldingsCaption
        )
    }

    private func createOptionViewModels(
        wallet: MetaAccountModel,
        language: Language,
        currency: Currency,
        locale: Locale,
        missingAccountIssue: [ChainIssue]
    ) -> [ProfileOptionViewModelProtocol] {
        ProfileOption.allCases.compactMap { option -> ProfileOptionViewModel? in
            switch option {
            case .walletConnect:
                return createWalletConnectViewModel(locale: locale)
            case .accountList:
                return createAccountListViewModel(
                    for: locale,
                    missingEthAccount: missingAccountIssue.isNotEmpty
                )
            case .changePincode:
                return createChangePincode(for: locale)
            case .language:
                return createLanguageViewModel(from: language, locale: locale)
            case .polkaswapDisclaimer:
                return createPolkaswapDisclaimer(locale: locale)
            case .about:
                return createAboutViewModel(for: locale)
            case .biometry:
                return createBiometryViewModel()
            case .currency:
                return createCurrencyViewModel(from: currency, locale: locale)
            case .accountScore:
                return createAccountScoreViewModel(locale: locale)
            case .networkAssets:
                return createNetworkAssetsViewModel()
            case .tonConnect:
                let hasTonAccount = wallet.legacyTonAccount != nil || wallet.chainAccounts.contains {
                    UniversalWalletChainAccountSupport.chainId(
                        $0.chainId,
                        matches: UniversalWalletRegistry.tonMainnetRegistryEntry.chainId
                    )
                }
                return createTonConnectViewModel(hasTonAccount: hasTonAccount)
            case .previousData, .emergencyMaterial:
                return ProfileOptionViewModel(
                    title: RecoveryText.string(option == .previousData ? "previous_data" : "export"),
                    icon: UIImage(systemName: "archivebox"),
                    accessoryTitle: nil,
                    accessoryImage: nil,
                    accessoryType: .arrow,
                    option: option
                )
            case .irohaConnect:
                return irohaConnectPolicy.isEnabled ? createIrohaConnectViewModel() : nil
            }
        }
    }

    private func createWalletConnectViewModel(locale _: Locale) -> ProfileOptionViewModel {
        ProfileOptionViewModel(
            title: "Wallet connect",
            icon: R.image.iconWalletConnect(),
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .walletConnect
        )
    }

    private func createNetworkAssetsViewModel() -> ProfileOptionViewModel {
        ProfileOptionViewModel(
            title: NSLocalizedString("settings.networks_assets", value: "Networks & Assets", comment: ""),
            icon: UIImage(systemName: "point.3.connected.trianglepath.dotted"),
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .networkAssets
        )
    }

    private func createTonConnectViewModel(hasTonAccount: Bool) -> ProfileOptionViewModel {
        ProfileOptionViewModel(
            title: "TonConnect",
            icon: UIImage(systemName: "link.circle"),
            accessoryTitle: hasTonAccount
                ? nil
                : NSLocalizedString("settings.ton_account_required", value: "TON account required", comment: ""),
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .tonConnect
        )
    }

    private func createIrohaConnectViewModel() -> ProfileOptionViewModel {
        ProfileOptionViewModel(
            title: "IrohaConnect",
            icon: UIImage(systemName: "link.badge.plus"),
            accessoryTitle: "SORA 3",
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .irohaConnect
        )
    }

    private func createLogoutViewModel(locale: Locale) -> ProfileOptionViewModelProtocol {
        let title = R.string.localizable
            .profileLogoutTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsLogout()!,
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: nil
        )
    }

    private func createBiometryViewModel() -> ProfileOptionViewModel? {
        let title: String
        switch biometry.availableBiometryType {
        case .none:
            return nil
        case .touchId:
            title = "Touch ID"
        case .faceId:
            title = "Face ID"
        }

        return ProfileOptionViewModel(
            title: title,
            icon: biometry.availableBiometryType.accessoryIconSettings,
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .switcher(settings.biometryEnabled ?? false),
            option: .biometry
        )
    }

    private func createAccountListViewModel(
        for locale: Locale,
        missingEthAccount: Bool
    ) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileWalletsTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsWallet()!,
            accessoryTitle: nil,
            accessoryImage: missingEthAccount ? R.image.iconWarning() : nil,
            accessoryType: .arrow,
            option: .accountList
        )
    }

    private func createChangePincode(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsPin()!,
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .changePincode
        )
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .languageTitle(preferredLanguages: locale.rLanguages)
        let subtitle = language?.title(in: locale)?.capitalized
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsLanguage()!,
            accessoryTitle: subtitle,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .language
        )
    }

    private func createPolkaswapDisclaimer(locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .polkaswapDisclaimerSettings(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.pinkPolkaswap()!,
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .polkaswapDisclaimer
        )
    }

    private func createAboutViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .aboutTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsWebsite()!,
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .about
        )
    }

    private func createCurrencyViewModel(from currency: Currency, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .commonCurrency(preferredLanguages: locale.rLanguages)
        let subtitle = currency.id.uppercased()
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconCurrency()!,
            accessoryTitle: subtitle,
            accessoryImage: nil,
            accessoryType: .arrow,
            option: .currency
        )
    }

    private func createAccountScoreViewModel(locale: Locale) -> ProfileOptionViewModel? {
        ProfileOptionViewModel(
            title: R.string.localizable.profileAccountScoreTitle(preferredLanguages: locale.rLanguages),
            icon: R.image.iconProfleAccountScore(),
            accessoryTitle: nil,
            accessoryImage: nil,
            accessoryType: .switcher(settings.accountScoreEnabled ?? false),
            option: .accountScore
        )
    }

    // MARK: Additional

    private func getDayChangeAttributedString(
        currency: Currency,
        dayChange: Decimal,
        dayChangeValue: Decimal,
        locale: Locale
    ) -> NSAttributedString? {
        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)
        let dayChangePercent = dayChange.percentString(locale: locale) ?? ""

        var dayChangeValue: String = balanceTokenFormatterValue.stringFromDecimal(abs(dayChangeValue)) ?? ""
        dayChangeValue = "(\(dayChangeValue))"
        let priceWithChangeString = [dayChangePercent, dayChangeValue].joined(separator: " ")
        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = dayChange > 0
            ? R.color.colorGreen()
            : R.color.colorRed()

        if let color = color, let colorLightGray = R.color.colorStrokeGray() {
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: color],
                range: NSRange(
                    location: 0,
                    length: dayChangePercent.count
                )
            )
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: colorLightGray],
                range: NSRange(
                    location: dayChangePercent.count + 1,
                    length: dayChangeValue.count
                )
            )
        }

        return priceWithChangeAttributed
    }
}
