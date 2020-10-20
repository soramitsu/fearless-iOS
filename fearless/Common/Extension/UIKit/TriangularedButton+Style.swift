import Foundation
import SoraUI

extension TriangularedButton {
    func applyDefaultStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorDarkBlue()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorDarkBlue()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }
}
