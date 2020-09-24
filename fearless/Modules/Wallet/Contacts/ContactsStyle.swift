import Foundation
import CommonWallet

extension ContactsViewStyle {
    static var fearless: ContactsViewStyle {
        ContactsViewStyle(backgroundColor: R.color.colorBlack()!,
                          searchHeaderBackgroundColor: R.color.colorBlack()!,
                          searchTextStyle: WalletTextStyle(font: UIFont.p1Paragraph, color: R.color.colorWhite()!),
                          searchFieldColor: .clear,
                          searchIndicatorStyle: R.color.colorGray()!,
                          searchIcon: nil,
                          separatorColor: R.color.colorDarkGray()!,
                          actionsSeparator: WalletStrokeStyle(color: .clear, lineWidth: 0.0))
    }
}

extension ContactCellStyle {
    static var fearless: ContactCellStyle {
        let iconStyle = WalletNameIconStyle(background: .white,
                                            title: WalletTextStyle(font: UIFont.p1Paragraph, color: .black),
                                            radius: 12.0)
        return ContactCellStyle(title: WalletTextStyle(font: UIFont.p1Paragraph, color: .white),
                                nameIcon: iconStyle,
                                accessoryIcon: R.image.iconSmallArrow())
    }
}
