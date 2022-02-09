import Foundation
import SoraFoundation
import FearlessUtils
import IrohaCrypto

protocol ProfileViewModelFactoryProtocol: AnyObject {
    func createUserViewModel(from wallet: MetaAccountModel, locale: Locale) -> ProfileUserViewModelProtocol

    func createOptionViewModels(
        language: Language,
        locale: Locale
    ) -> [ProfileOptionViewModelProtocol]

    func createLogoutViewModel(locale: Locale) -> ProfileOptionViewModelProtocol
}

enum ProfileOption: UInt, CaseIterable {
    case accountList
    case language
    case changePincode
    case about
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createUserViewModel(from wallet: MetaAccountModel, locale _: Locale) -> ProfileUserViewModelProtocol {
        let icon = try? iconGenerator.generateFromAddress("")

        return ProfileUserViewModel(
            name: wallet.name,
            details: "",
            icon: icon
        )
    }

    func createOptionViewModels(
        language: Language,
        locale: Locale
    ) -> [ProfileOptionViewModelProtocol] {
        let optionViewModels = ProfileOption.allCases.compactMap { (option) -> ProfileOptionViewModel? in
            switch option {
            case .accountList:
                return createAccountListViewModel(for: locale)
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

    func createLogoutViewModel(locale: Locale) -> ProfileOptionViewModelProtocol {
        let title = R.string.localizable
            .profileLogoutTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsLogout()!,
            accessoryTitle: nil
        )
        return viewModel
    }

    private func createAccountListViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileWalletsTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsWallet()!,
            accessoryTitle: nil
        )
        return viewModel
    }

    private func createConnectionListViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileNetworkTitle(preferredLanguages: locale.rLanguages)

        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconProfileNetworks()!,
            accessoryTitle: nil
        )

        return viewModel
    }

    private func createChangePincode(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsPin()!,
            accessoryTitle: nil
        )
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileLanguageTitle(preferredLanguages: locale.rLanguages)
        let subtitle = language?.title(in: locale)?.capitalized
        let viewModel = ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsLanguage()!,
            accessoryTitle: subtitle
        )

        return viewModel
    }

    private func createAboutViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileAboutTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(
            title: title,
            icon: R.image.iconSettingsWebsite()!,
            accessoryTitle: nil
        )
    }
}
