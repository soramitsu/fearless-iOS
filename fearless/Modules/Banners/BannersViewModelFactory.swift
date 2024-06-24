import Foundation

struct BannersViewModel {
    let banners: [BannerCellViewModel]
}

enum Banners: Int {
    case backup
    case buyXor
    case liquidityPools
}

protocol BannersViewModelFactoryProtocol {
    func createViewModel(
        wallet: MetaAccountModel,
        locale: Locale
    ) -> BannersViewModel

    func createViewModel(banners: [Banners], locale: Locale) -> BannersViewModel
}

final class BannersViewModelFactory: BannersViewModelFactoryProtocol {
    func createViewModel(banners: [Banners], locale: Locale) -> BannersViewModel {
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
                    dismissable: true,
                    fullsizeImage: false,
                    bannerType: .backup
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
                    dismissable: true,
                    fullsizeImage: false,
                    bannerType: .buyXor
                )
            case .liquidityPools:
                let title = "Liquidity pools"
                let subtitle = "Invest your funds in Liquidity pools and receive rewards"
                let buttonAction = "Show details"

                return BannerCellViewModel(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.iconLpBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: .liquidityPools
                )
            }
        }

        return BannersViewModel(banners: bannersViewModel)
    }

    func createViewModel(
        wallet: MetaAccountModel,
        locale: Locale
    ) -> BannersViewModel {
        var banners: [Banners] = []
        if !wallet.hasBackup {
            banners.insert(.backup, at: 0)
        }

        return createViewModel(banners: banners, locale: locale)
    }
}
