import Foundation
import SoraFoundation
import FearlessUtils
import IrohaCrypto

protocol ProfileViewModelFactoryProtocol: AnyObject {
    func createUserViewModel(from settings: UserSettings, locale: Locale) -> ProfileUserViewModelProtocol

    func createOptionViewModels(
        from settings: UserSettings,
        language: Language,
        locale: Locale
    ) -> [ProfileOptionViewModelProtocol]
}

enum ProfileOption: UInt, CaseIterable {
    case accountList
    case connectionList
    case language
    case changePincode
    case about
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createUserViewModel(from settings: UserSettings, locale _: Locale) -> ProfileUserViewModelProtocol {
        let icon = try? iconGenerator.generateFromAddress(settings.account.address)

        return ProfileUserViewModel(
            name: settings.account.username,
            details: settings.account.address,
            icon: icon
        )
    }

    func createOptionViewModels(
        from settings: UserSettings,
        language: Language,
        locale: Locale
    ) -> [ProfileOptionViewModelProtocol] {
        let optionViewModels = ProfileOption.allCases.compactMap { (option) -> ProfileOptionViewModel? in
            switch option {
            case .accountList:
                return createAccountListViewModel(for: locale)
            case .connectionList:
                return createConnectionListViewModel(from: settings.connection, locale: locale)
            case .changePincode:
                return createChangePincode(for: locale)
            case .language:
                return createLanguageViewModel(from: language, locale: locale)
            case .about:
                return createAboutViewModel(for: locale)
            }
        }

        return optionViewModels
    }

    private func createAccountListViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileAccountsTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconProfileAccounts()!,
            accessoryTitle: nil
        )
        return viewModel
    }

    private func createConnectionListViewModel(
        from connection: ConnectionItem,
        locale: Locale
    ) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileNetworkTitle(preferredLanguages: locale.rLanguages)

        let subtitle: String = connection.type.titleForLocale(locale)

        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconProfileNetworks()!,
            accessoryTitle: subtitle
        )

        return viewModel
    }

    private func createChangePincode(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconProfilePin()!,
            accessoryTitle: nil
        )
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileLanguageTitle(preferredLanguages: locale.rLanguages)
        let subtitle = language?.title(in: locale)?.capitalized
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconProfileLanguage()!,
            accessoryTitle: subtitle
        )

        return viewModel
    }

    private func createAboutViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileAboutTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconProfileAbout()!,
            accessoryTitle: nil
        )
    }
}
