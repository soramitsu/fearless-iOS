import Foundation
import SoraUI
import UIKit

extension TriangularedButton {
    func applyAccessoryStyle() {
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = .clear
        triangularedView?.highlightedFillColor = .clear
        triangularedView?.strokeColor = R.color.colorDarkGray()!
        triangularedView?.highlightedStrokeColor = R.color.colorDarkGray()!
        triangularedView?.strokeWidth = 2

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }

    func applyStackButtonStyle() {
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = R.color.colorSemiBlack()!
        triangularedView?.highlightedFillColor = R.color.colorSemiBlack()!
        triangularedView?.strokeColor = R.color.colorDarkGray()!
        triangularedView?.highlightedStrokeColor = R.color.colorDarkGray()!
        triangularedView?.strokeWidth = 1

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = .h6Title

        changesContentOpacityWhenHighlighted = true
    }

    func applyEnabledStyle() {
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = R.color.colorPink()!
        triangularedView?.highlightedFillColor = R.color.colorPink()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = .h4Title

        changesContentOpacityWhenHighlighted = true
    }

    func applyDisabledStyle() {
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = R.color.colorBlack1()!
        triangularedView?.highlightedFillColor = R.color.colorBlack1()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = UIColor.white
        imageWithTitleView?.titleFont = .h4Title

        contentOpacityWhenDisabled = 1
    }

    func applyLoadingStyle() {
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = R.color.colorDarkGray()!
        triangularedView?.highlightedFillColor = R.color.colorDarkGray()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = .clear
        imageWithTitleView?.titleFont = .h4Title

        contentOpacityWhenDisabled = 1
    }
}
