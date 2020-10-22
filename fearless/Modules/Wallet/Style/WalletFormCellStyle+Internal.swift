import Foundation
import CommonWallet

extension WalletFormCellStyle {
    static var fearless: WalletFormCellStyle {
        let title = WalletTextStyle(font: UIFont.p1Paragraph,
                                    color: R.color.colorLightGray()!)
        let details = WalletTextStyle(font: UIFont.p1Paragraph,
                                      color: R.color.colorWhite()!)

        let link = WalletLinkStyle(normal: R.color.colorWhite()!,
                                        highlighted: R.color.colorDarkBlue()!)

        return WalletFormCellStyle(title: title,
                                   details: details,
                                   link: link,
                                   separator: R.color.colorDarkGray()!)
    }
}
