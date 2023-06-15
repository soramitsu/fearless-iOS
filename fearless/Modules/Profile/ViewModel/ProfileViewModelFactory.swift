import Foundation
import SoraFoundation
import SSFUtils
import IrohaCrypto
import SoraKeystore

protocol ProfileViewModelFactoryProtocol: AnyObject {
    func createProfileViewModel(
        from wallet: MetaAccountModel,
        locale: Locale,
        language: Language,
        currency: Currency,
        balance: WalletBalanceInfo?
    ) -> ProfileViewModelProtocol
}

enum ProfileOption: UInt, CaseIterable {
    case accountList
    case currency
    case language
    case polkaswapDisclaimer
    case changePincode
    case biometry
    case about
    case zeroBalances
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {
    // MARK: - Private properties

    private let iconGenerator: IconGenerating
    private let biometry: BiometryAuthProtocol
    private let settings: SettingsManagerProtocol
    private lazy var assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

    // MARK: - Constructors

    init(
        iconGenerator: IconGenerating,
        biometry: BiometryAuthProtocol,
        settings: SettingsManagerProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.biometry = biometry
        self.settings = settings
    }

    // MARK: - Public methods

    func createProfileViewModel(
        from wallet: MetaAccountModel,
        locale: Locale,
        language: Language,
        currency: Currency,
        balance: WalletBalanceInfo?
    ) -> ProfileViewModelProtocol {
        let profileUserViewModel = createUserViewModel(
            from: wallet,
            balance: balance,
            locale: locale
        )
        let profileOptionViewModel = createOptionViewModels(
            language: language,
            currency: currency,
            locale: locale,
            wallet: wallet
        )
        let logoutViewModel = createLogoutViewModel(locale: locale)
        let viewModel = ProfileViewModel(
            profileUserViewModel: profileUserViewModel,
            profileOptionViewModel: profileOptionViewModel,
            logoutViewModel: logoutViewModel
        )
        return viewModel
    }

    // MARK: - Private methods

    private func tokenFormatter(for currency: Currency, locale: Locale) -> TokenFormatter {
        let balanceDisplayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let balanceTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: balanceDisplayInfo, usageCase: .detailsCrypto)
        let balanceTokenFormatterValue = balanceTokenFormatter.value(for: locale)
        return balanceTokenFormatterValue
    }

    private func createUserViewModel(
        from wallet: MetaAccountModel,
        balance: WalletBalanceInfo?,
        locale: Locale
    ) -> ProfileUserViewModelProtocol {
        let icon = try? iconGenerator.generateFromAddress("")

        var details: String = ""
        if let balance = balance {
            let formatter = tokenFormatter(for: balance.currency, locale: locale)
            details = formatter.stringFromDecimal(balance.totalFiatValue) ?? ""
        }

        return ProfileUserViewModel(
            name: wallet.name,
            details: details,
            icon: icon
        )
    }

    private func createOptionViewModels(
        language: Language,
        currency: Currency,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> [ProfileOptionViewModelProtocol] {
        let optionViewModels = ProfileOption.allCases.compactMap { (option) -> ProfileOptionViewModel? in
            switch option {
            case .accountList:
                return createAccountListViewModel(for: locale)
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
            case .zeroBalances:
                return createZeroBalancesViewModel(for: locale, wallet: wallet)
            }
        }

        return optionViewModels
    }

    private func createLogoutViewModel(locale: Locale) -> ProfileOptionViewModelProtocol {
        let title = R.string.localizable
            .profileLogoutTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsLogout()!,
            accessoryTitle: nil,
            accessoryType: .arrow,
            option: nil
        )
        return viewModel
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

        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: biometry.availableBiometryType.accessoryIconSettings,
            accessoryTitle: nil,
            accessoryType: .switcher(settings.biometryEnabled ?? false),
            option: .biometry
        )
        return viewModel
    }

    private func createAccountListViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileWalletsTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsWallet()!,
            accessoryTitle: nil,
            accessoryType: .arrow,
            option: .accountList
        )
        return viewModel
    }

    private func createChangePincode(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsPin()!,
            accessoryTitle: nil,
            accessoryType: .arrow,
            option: .changePincode
        )
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .languageTitle(preferredLanguages: locale.rLanguages)
        let subtitle = language?.title(in: locale)?.capitalized
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsLanguage()!,
            accessoryTitle: subtitle,
            accessoryType: .arrow,
            option: .language
        )

        return viewModel
    }

    private func createPolkaswapDisclaimer(locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .polkaswapDisclaimerSettings(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.pinkPolkaswap()!,
            accessoryTitle: nil,
            accessoryType: .arrow,
            option: .polkaswapDisclaimer
        )

        return viewModel
    }

    private func createAboutViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .aboutTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsWebsite()!,
            accessoryTitle: nil,
            accessoryType: .arrow,
            option: .about
        )
    }

    private func createZeroBalancesViewModel(for locale: Locale, wallet: MetaAccountModel) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileHideZeroBalancesTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconZeroBalances()!,
            accessoryTitle: nil,
            accessoryType: .switcher(wallet.zeroBalanceAssetsHidden),
            option: .zeroBalances
        )
    }

    private func createCurrencyViewModel(from currency: Currency, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .commonCurrency(preferredLanguages: locale.rLanguages)
        let subtitle = currency.id.uppercased()
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconCurrency()!,
            accessoryTitle: subtitle,
            accessoryType: .arrow,
            option: .currency
        )

        return viewModel
    }
}
