import Foundation
import CommonWallet

struct AssetStyleFactory: AssetCellStyleFactoryProtocol {
    func createCellStyle(for _: WalletAsset) -> AssetCellStyle {
        let shadow = WalletShadowStyle(
            offset: CGSize(width: 0.0, height: 0.0),
            color: UIColor.black,
            opacity: 0.0,
            blurRadius: 0.0
        )

        let textColor = R.color.colorWhite()!
        let subtitleColor = UIColor(white: 136.0 / 255.0, alpha: 1.0)
        let headerFont = R.font.soraRc0040417SemiBold(size: 18)!
        let regularFont = R.font.soraRc0040417Regular(size: 14)!

        let cardStyle = CardAssetStyle(
            backgroundColor: UIColor.black.withAlphaComponent(0.7),
            leftFillColor: UIColor.black.withAlphaComponent(0.0),
            symbol: WalletTextStyle(font: headerFont, color: R.color.colorWhite()!),
            title: WalletTextStyle(font: headerFont, color: textColor),
            subtitle: WalletTextStyle(font: regularFont, color: subtitleColor),
            accessory: WalletTextStyle(font: regularFont, color: textColor),
            shadow: shadow,
            cornerRadius: 10.0
        )

        return .card(cardStyle)
    }
}
