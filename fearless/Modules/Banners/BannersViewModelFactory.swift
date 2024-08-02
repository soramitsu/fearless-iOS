import Foundation
import SSFModels

struct BannersViewModel {
    let banners: [BannerCellViewModel]
}

enum Banners: Int {
    case backup
    case buyXor
    case liquidityPools
    case liquidityPoolsTest
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
                let title = R.string.localizable.balanceLocksLiquidityPoolsRowTitle(preferredLanguages: locale.rLanguages)
                let subtitle = R.string.localizable.lpBannerText(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable.lpBannerActionDetailsTitle(preferredLanguages: locale.rLanguages)

                return BannerCellViewModel(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.iconLpBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: .liquidityPools
                )

            case .liquidityPoolsTest:
                let title = "Liquidity pools test"
                let subtitle = R.string.localizable.lpBannerText(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable.lpBannerActionDetailsTitle(preferredLanguages: locale.rLanguages)

                return BannerCellViewModel(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.iconLpBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: .liquidityPoolsTest
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
