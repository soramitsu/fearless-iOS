import Foundation
import SSFModels
import SCard

struct BannersViewModel {
    let banners: [CollectionViewModel]
}

enum Banners: Int {
    case backup
    case buyXor
    case liquidityPools
    case liquidityPoolsTest
    case addRegularWallet
    case addTonWallet
    case soraCard
}

protocol BannersViewModelFactoryProtocol {
    func createViewModel(
        wallets: [MetaAccountModel],
        soraCardStatus: KYCUserStatus?,
        delegate: BannerCellDelegate?,
        locale: Locale,
        shouldShowAddWalletBanner: Bool
    ) -> BannersViewModel

    func createViewModel(
        banners: [Banners],
        delegate: BannerCellDelegate?,
        locale: Locale
    ) -> BannersViewModel
}

final class BannersViewModelFactory: BannersViewModelFactoryProtocol {
    func createViewModel(
        banners: [Banners],
        delegate: BannerCellDelegate?,
        locale: Locale
    ) -> BannersViewModel {
        let bannersViewModel: [CollectionViewModel] = banners.compactMap { bannerType in
            switch bannerType {
            case .backup:
                let title = R.string.localizable
                    .bannersViewFactoryBackupTitle(preferredLanguages: locale.rLanguages)
                let subtitle = R.string.localizable
                    .bannersViewFactoryBackupSubtitle(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable
                    .bannersViewFactoryBackupActionTitle(preferredLanguages: locale.rLanguages)
                return BannerCellViewModelDefault(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.fearlessBanner()!,
                    dismissable: true,
                    fullsizeImage: false,
                    bannerType: bannerType,
                    delegate: delegate
                )
            case .buyXor:
                let title = R.string.localizable
                    .bannersViewFactoryXorTitle(preferredLanguages: locale.rLanguages)
                let subtitle = R.string.localizable
                    .bannersViewFactoryXorSubtitle(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable
                    .bannersViewFactoryXorActionTitle(preferredLanguages: locale.rLanguages)
                return BannerCellViewModelDefault(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.xorBanner()!,
                    dismissable: true,
                    fullsizeImage: false,
                    bannerType: bannerType,
                    delegate: delegate
                )
            case .liquidityPools:
                let title = R.string.localizable.balanceLocksLiquidityPoolsRowTitle(preferredLanguages: locale.rLanguages)
                let subtitle = R.string.localizable.lpBannerText(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable.lpBannerActionDetailsTitle(preferredLanguages: locale.rLanguages)

                return BannerCellViewModelDefault(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.iconLpBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: bannerType,
                    delegate: delegate
                )

            case .liquidityPoolsTest:
                let title = "Liquidity pools test"
                let subtitle = R.string.localizable.lpBannerText(preferredLanguages: locale.rLanguages)
                let buttonAction = R.string.localizable.lpBannerActionDetailsTitle(preferredLanguages: locale.rLanguages)

                return BannerCellViewModelDefault(
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: buttonAction,
                    image: R.image.iconLpBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: bannerType,
                    delegate: delegate
                )
            case .addRegularWallet:
                return BannerCellViewModelDefault(
                    title: R.string.localizable.bannerAddwalletRegularTitle(preferredLanguages: locale.rLanguages),
                    subtitle: R.string.localizable.bannerAddwalletRegularSubtitle(preferredLanguages: locale.rLanguages),
                    buttonTitle: R.string.localizable.bannerAddwalletRegularButtonTitle(preferredLanguages: locale.rLanguages),
                    image: R.image.regularBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: bannerType,
                    delegate: delegate
                )
            case .addTonWallet:
                return BannerCellViewModelDefault(
                    title: R.string.localizable.bannerAddwalletTonTitle(preferredLanguages: locale.rLanguages),
                    subtitle: "",
                    buttonTitle: R.string.localizable.bannerAddwalletTonButtonTitle(preferredLanguages: locale.rLanguages),
                    image: R.image.tonBanner()!,
                    dismissable: true,
                    fullsizeImage: true,
                    bannerType: bannerType,
                    delegate: delegate
                )
            case .soraCard:
                return BannerCellViewModelDefault(
                    title: "Get SORA Card",
                    subtitle: "Get a Euro IBAN bank\naccount and a debit card",
                    buttonTitle: "View details",
                    image: UIImage(named: "soraCardBanner")!,
                    dismissable: true,
                    fullsizeImage: false,
                    bannerType: bannerType,
                    delegate: delegate
                )
            }
        }

        return BannersViewModel(banners: bannersViewModel)
    }

    func createViewModel(
        wallets: [MetaAccountModel],
        soraCardStatus: KYCUserStatus?,
        delegate: BannerCellDelegate?,
        locale: Locale,
        shouldShowAddWalletBanner: Bool
    ) -> BannersViewModel {
        var banners: [Banners] = []
//        if let wallet = SelectedWalletSettings.shared.value, !wallet.hasBackup {
            banners.insert(.backup, at: 0)
//        }

//        if shouldShowAddWalletBanner {
//            let divided = wallets.divide(predicate: { $0.ecosystem.isRegular })
//            if divided.slice.isEmpty {
                banners.append(.addRegularWallet)
//            } else if divided.remainder.isEmpty {
                banners.append(.addTonWallet)
//            }
//        }
        
        if soraCardStatus == .notStarted {
            banners.append(.soraCard)
        }
        
        if soraCardStatus == .successful {
            banners.append(.buyXor)
        }
        
        return createViewModel(
            banners: banners,
            delegate: delegate,
            locale: locale
        )
    }
}
