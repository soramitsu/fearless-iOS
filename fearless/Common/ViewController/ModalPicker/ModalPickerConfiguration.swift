import Foundation
import SoraUI

extension ModalSheetPresentationStyle {
    static var fearless: ModalSheetPresentationStyle {
        let indicatorSize = CGSize(width: 35.0, height: 2.0)
        let headerStyle = ModalSheetPresentationHeaderStyle(preferredHeight: 20.0,
                                                            backgroundColor: R.color.colorBlack()!,
                                                            cornerRadius: 20.0,
                                                            indicatorVerticalOffset: 2.0,
                                                            indicatorSize: indicatorSize,
                                                            indicatorColor: R.color.colorLightGray()!)
        let style = ModalSheetPresentationStyle(backdropColor: R.color.colorScrim()!,
                                                headerStyle: headerStyle)
        return style
    }
}

extension ModalSheetPresentationConfiguration {
    static var fearless: ModalSheetPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(duration: 0.25,
                                                   delay: 0.0,
                                                   options: [.curveEaseOut])
        let dismissalAnimator = BlockViewAnimator(duration: 0.25,
                                                  delay: 0.0,
                                                  options: [.curveLinear])

        let configuration = ModalSheetPresentationConfiguration(contentAppearanceAnimator: appearanceAnimator,
                                                                contentDissmisalAnimator: dismissalAnimator,
                                                                style: ModalSheetPresentationStyle.fearless,
                                                                extendUnderSafeArea: true,
                                                                dismissFinishSpeedFactor: 0.6,
                                                                dismissCancelSpeedFactor: 0.6)
        return configuration
    }
}
