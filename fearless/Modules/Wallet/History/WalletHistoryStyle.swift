import Foundation
import CommonWallet

extension HistoryViewStyle {
    static var fearless: HistoryViewStyleProtocol {
        let borderStyle = WalletStrokeStyle(color: .clear, lineWidth: 0.0)
        let cornerRadius: CGFloat = 10.0
        let titleStyle = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 15.0)!,
                                         color: .white)

        return HistoryViewStyle(fillColor: UIColor.black.withAlphaComponent(0.4),
                                borderStyle: borderStyle,
                                cornerRadius: cornerRadius,
                                titleStyle: titleStyle,
                                filterIcon: nil,
                                closeIcon: nil,
                                panIndicatorStyle: UIColor.white)
    }
}
