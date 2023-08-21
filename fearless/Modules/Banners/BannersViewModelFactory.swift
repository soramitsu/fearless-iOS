import Foundation

struct BannersViewModel {
    let banners: [BannerCellViewModel]
}

enum Banners: Int {
    case backup
    case buyXor
}

protocol BannersViewModelFactoryProtocol {
    func createViewModel(
        wallet: MetaAccountModel,
        locale: Locale
    ) -> BannersViewModel
}

final class BannersViewModelFactory: BannersViewModelFactoryProtocol {
    func createViewModel(
        wallet: MetaAccountModel,
        locale: Locale
    ) -> BannersViewModel {
        var banners: [Banners] = []
        if !wallet.hasBackup {
            banners.insert(.backup, at: 0)
        }
        let bannersViewModel: [BannerCellViewModel] = banners.map {
            switch $0 {
            case .backup:
                let title = R.string.localizable
                    .bannersViewFactoryBackupTitle(preferredLanguages: locale.rLanguages)
                let subtitle = R.string.localizable
                    .bannersViewFactoryBackupSubtitle(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable
                    .bannersViewFactoryBackupActionTitle(preferredLanguages: locale.rLanguages)
                return BannerCellViewModel(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.fearlessBanner()!,
                    dismissable: true
                )
            case .buyXor:
                let title = R.string.localizable
                    .bannersViewFactoryXorTitle(preferredLanguages: locale.rLanguages)
                let subtitle = R.string.localizable
                    .bannersViewFactoryXorSubtitle(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable
                    .bannersViewFactoryXorActionTitle(preferredLanguages: locale.rLanguages)
                return BannerCellViewModel(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.xorBanner()!,
                    dismissable: true
                )
            }
        }

        return BannersViewModel(banners: bannersViewModel)
    }
}
