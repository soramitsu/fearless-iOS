import Foundation
import SoraUI

extension TriangularedButton {
    func applyDefaultStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorDarkBlue()!
        triangularedView?.highlightedFillColor = R.color.colorDarkBlue()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }

    func applyAccessoryStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = .clear
        triangularedView?.highlightedFillColor = .clear
        triangularedView?.strokeColor = R.color.colorDarkGray()!
        triangularedView?.highlightedStrokeColor = R.color.colorDarkGray()!
        triangularedView?.strokeWidth = 2.0

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }
}
