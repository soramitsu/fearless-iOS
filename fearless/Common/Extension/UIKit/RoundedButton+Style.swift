import Foundation
import SoraUI

extension RoundedButton {
    func applyEnabledStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorDarkGray()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorDarkGray()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite()!

        changesContentOpacityWhenHighlighted = true
    }

    func applyDisabledStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorAlmostBlack()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorAlmostBlack()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorDarkGray()

        contentOpacityWhenDisabled = 1.0
    }

    func applySoraSecondaryStyle() {
        roundedBackgroundView?.shadowOpacity = 0
        roundedBackgroundView?.fillColor = R.color.accentSecondary()!
        roundedBackgroundView?.highlightedFillColor = R.color.accentSecondary()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear
        roundedBackgroundView?.strokeWidth = 2

        imageWithTitleView?.titleColor = R.color.fgInverted()!
        imageWithTitleView?.titleFont = UIFont.h4Title

        changesContentOpacityWhenHighlighted = true
    }
}
