import Foundation
import CommonWallet

final class WalletHistoryBackgroundView: TriangularedBlurView {
    let minimizedSideLength: CGFloat = 10.0
}

extension WalletHistoryBackgroundView: HistoryBackgroundViewProtocol {
    func apply(style: HistoryViewStyleProtocol) {}

    func applyFullscreen(progress: CGFloat) {
        sideLength = minimizedSideLength * progress
    }
}
