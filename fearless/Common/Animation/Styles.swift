import Foundation
import SoraUI

extension ModalSheetPresentationStyle {
    static var fearlessBlur: ModalSheetPresentationStyle {
        let style = ModalSheetPresentationStyle(
            backdropColor: .clear,
            headerStyle: nil
        )
        return style
    }
}

extension ModalSheetPresentationConfiguration {
    static var fearlessBlur: ModalSheetPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveEaseOut]
        )
        let dismissalAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveLinear]
        )

        let configuration = ModalSheetPresentationConfiguration(
            contentAppearanceAnimator: appearanceAnimator,
            contentDissmisalAnimator: dismissalAnimator,
            style: ModalSheetPresentationStyle.fearlessBlur,
            extendUnderSafeArea: true,
            dismissFinishSpeedFactor: 0.6,
            dismissCancelSpeedFactor: 0.6
        )
        return configuration
    }
}
