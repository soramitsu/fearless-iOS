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
        locale _: Locale
    ) -> BannersViewModel {
        var banners: [Banners] = []
        if !wallet.isBackuped {
            banners.insert(.backup, at: 0)
        }
        let bannersViewModel: [BannerCellViewModel] = banners.map {
            switch $0 {
            case .backup:
                return BannerCellViewModel(
                    title: "Backup your wallet",
                    subtitle: "If you loose your device, you will lose your funds forever",
                    buttonTitle: "Backup now",
                    image: R.image.fearlessBanner()!
                )
            case .buyXor:
                return BannerCellViewModel(
                    title: "Buy XOR token",
                    subtitle: "Buy or sell XOR token with Euro cash",
                    buttonTitle: "Buy XOR",
                    image: R.image.xorBanner()!
                )
            }
        }

        return BannersViewModel(banners: bannersViewModel)
    }
}
