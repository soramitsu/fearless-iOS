import Foundation
import SoraUI

extension ModalInputPresentationStyle {
    static var fearless: ModalInputPresentationStyle {
        let indicatorSize = CGSize(width: 35.0, height: 2.0)
        let headerStyle = ModalInputPresentationHeaderStyle(preferredHeight: 20.0,
                                                            backgroundColor: R.color.colorBlack()!,
                                                            cornerRadius: 20.0,
                                                            indicatorVerticalOffset: 2.0,
                                                            indicatorSize: indicatorSize,
                                                            indicatorColor: R.color.colorLightGray()!)
        let style = ModalInputPresentationStyle(backdropColor: R.color.colorScrim()!,
                                                headerStyle: headerStyle)
        return style
    }
}

extension ModalInputPresentationConfiguration {
    static var fearless: ModalInputPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(duration: 0.25,
                                                   delay: 0.0,
                                                   options: [.curveEaseOut])
        let dismissalAnimator = BlockViewAnimator(duration: 0.25,
                                                  delay: 0.0,
                                                  options: [.curveLinear])

        let configuration = ModalInputPresentationConfiguration(contentAppearanceAnimator: appearanceAnimator,
                                                                contentDissmisalAnimator: dismissalAnimator,
                                                                style: ModalInputPresentationStyle.fearless,
                                                                extendUnderSafeArea: true,
                                                                dismissFinishSpeedFactor: 0.6,
                                                                dismissCancelSpeedFactor: 0.6)
        return configuration
    }
}
