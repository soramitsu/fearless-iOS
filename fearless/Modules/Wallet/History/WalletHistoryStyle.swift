import Foundation
import CommonWallet

extension HistoryViewStyle {
    static var fearless: HistoryViewStyleProtocol {
        let borderStyle = WalletStrokeStyle(color: .clear, lineWidth: 0.0)
        let cornerRadius: CGFloat = 10.0
        let titleStyle = WalletTextStyle(
            font: .p0Paragraph,
            color: R.color.colorWhite()!
        )

        return HistoryViewStyle(
            fillColor: UIColor.black.withAlphaComponent(0.7),
            borderStyle: borderStyle,
            cornerRadius: cornerRadius,
            titleStyle: titleStyle,
            filterIcon: R.image.iconFilter(),
            closeIcon: R.image.iconClose(),
            panIndicatorStyle: R.color.colorWhite()!,
            shouldInsertFullscreenShadow: false,
            shadow: nil,
            separatorStyle: nil,
            pageLoadingIndicatorColor: R.color.colorTransparentText()
        )
    }
}
