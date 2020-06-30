import Foundation
import CommonWallet

struct AssetStyleFactory: AssetCellStyleFactoryProtocol {
    func createCellStyle(for asset: WalletAsset) -> AssetCellStyle {
        let shadow = WalletShadowStyle(offset: CGSize(width: 0.0, height: 5.0),
                                       color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.1),
                                       opacity: 1.0,
                                       blurRadius: 25.0)

        let textColor = UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1)
        let headerFont = R.font.soraRc0040417SemiBold(size: 18)!
        let regularFont = R.font.soraRc0040417Regular(size: 14)!

        let cardStyle = CardAssetStyle(backgroundColor: .white,
                                       leftFillColor: .black,
                                       symbol: WalletTextStyle(font: headerFont, color: UIColor.white),
                                       title: WalletTextStyle(font: headerFont, color: textColor),
                                       subtitle: WalletTextStyle(font: regularFont, color: textColor),
                                       accessory: WalletTextStyle(font: regularFont, color: textColor),
                                       shadow: shadow,
                                       cornerRadius: 10.0)

        return .card(cardStyle)
    }
}
