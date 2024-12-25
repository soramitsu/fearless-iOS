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
    case addRegularWallet
    case addTonWallet
}

protocol BannersViewModelFactoryProtocol {
    func createViewModel(
        wallets: [MetaAccountModel],
        locale: Locale,
        shouldShowAddWalletBanner: Bool
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
            case .addRegularWallet:
                return BannerCellViewModel(
                    title: R.string.localizable.bannerAddwalletRegularTitle(preferredLanguages: locale.rLanguages),
                    subtitle: R.string.localizable.bannerAddwalletRegularSubtitle(preferredLanguages: locale.rLanguages),
                    buttonTitle: R.string.localizable.bannerAddwalletRegularButtonTitle(preferredLanguages: locale.rLanguages),
                    image: R.image.regularBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: $0
                )
            case .addTonWallet:
                return BannerCellViewModel(
                    title: R.string.localizable.bannerAddwalletTonTitle(preferredLanguages: locale.rLanguages),
                    subtitle: "",
                    buttonTitle: R.string.localizable.bannerAddwalletTonButtonTitle(preferredLanguages: locale.rLanguages),
                    image: R.image.tonBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: $0
                )
            }
        }

        return BannersViewModel(banners: bannersViewModel)
    }

    func createViewModel(
        wallets: [MetaAccountModel],
        locale: Locale,
        shouldShowAddWalletBanner: Bool
    ) -> BannersViewModel {
        var banners: [Banners] = []
        if let wallet = SelectedWalletSettings.shared.value, !wallet.hasBackup {
            banners.insert(.backup, at: 0)
        }

        if shouldShowAddWalletBanner {
            let divided = wallets.divide(predicate: { $0.ecosystem.isRegular })
            if divided.slice.isEmpty {
                banners.append(.addRegularWallet)
            } else if divided.remainder.isEmpty {
                banners.append(.addTonWallet)
            }
        }

        return createViewModel(banners: banners, locale: locale)
    }
}
