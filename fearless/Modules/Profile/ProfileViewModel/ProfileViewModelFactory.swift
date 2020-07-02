import Foundation
import SoraFoundation

protocol ProfileViewModelFactoryProtocol: class {
    func createUserViewModel(from userData: UserData?, locale: Locale) -> ProfileUserViewModelProtocol
    func createOptionViewModels(language: Language?,
                                locale: Locale) -> [ProfileOptionViewModelProtocol]
}

enum ProfileOption: UInt, CaseIterable {
    case passphrase
    case connection
    case language
    case about
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {
    func createUserViewModel(from userData: UserData?, locale: Locale) -> ProfileUserViewModelProtocol {
        if let userData = userData {
            let details = R.string.localizable.profileSubtitle(preferredLanguages: locale.rLanguages)
            return ProfileUserViewModel(name: userData.address, details: details)
        } else {
            return ProfileUserViewModel(name: "", details: "")
        }
    }

    func createOptionViewModels(language: Language?,
                                locale: Locale) -> [ProfileOptionViewModelProtocol] {

        let optionViewModels = ProfileOption.allCases.compactMap { (option) -> ProfileOptionViewModel? in
            switch option {
            case .connection:
                return nil
            case .passphrase:
                return createPassphraseViewModel(for: locale)
            case .language:
                return createLanguageViewModel(from: language, locale: locale)
            case .about:
                return createAboutViewModel(for: locale)
            }
        }

        return optionViewModels
    }

    private func createPassphraseViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profilePassphraseTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(title: title, icon: R.image.iconProfilePassphrase()!)
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileLanguageTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(title: title, icon: R.image.iconProfileLanguage()!)

        viewModel.accessoryTitle = language?.title(in: locale)?.capitalized

        return viewModel
    }

    private func createAboutViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileAboutTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(title: title, icon: R.image.iconTermsProfile()!)
    }
}
