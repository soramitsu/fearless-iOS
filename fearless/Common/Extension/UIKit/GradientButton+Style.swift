import Foundation
import SoraUI

extension GradientButton {
    func applyDefaultStyle() {
        gradientBackgroundView?.startColor = R.color.colorAccentGradientStart()!
        gradientBackgroundView?.endColor = R.color.colorAccentGradientEnd()!
        gradientBackgroundView?.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientBackgroundView?.endPoint = CGPoint(x: 1.0, y: 0.5)

        imageWithTitleView?.titleColor = R.color.colorWhite()
        imageWithTitleView?.titleFont = .h6Title

        changesContentOpacityWhenHighlighted = true
    }

    func applyDisabledStyle() {
        gradientBackgroundView?.startColor = R.color.colorGradientDisabled()!
        gradientBackgroundView?.endColor = R.color.colorGradientDisabled()!

        imageWithTitleView?.titleColor = R.color.colorDarkGray()
        imageWithTitleView?.titleFont = .h6Title
    }
}
