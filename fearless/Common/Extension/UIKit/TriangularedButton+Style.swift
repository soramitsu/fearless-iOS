import Foundation
import SoraUI
import UIKit

extension TriangularedButton {
    /// Secondary action: a Raised-2 surface (sun-lit redesign).
    func applyAccessoryStyle() {
        fwStyleRole = .other
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = FWSunlit.Palette.background
        triangularedView?.highlightedFillColor = FWSunlit.Palette.backgroundDeep
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear
        triangularedView?.strokeWidth = 0
        triangularedView?.fwElevation = .raised2
        triangularedView?.fwInteractive = true

        imageWithTitleView?.titleColor = FWSunlit.Palette.textPrimary
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }

    /// A row of compact actions: Raised-1 chips.
    func applyStackButtonStyle() {
        fwStyleRole = .other
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = FWSunlit.Palette.background
        triangularedView?.highlightedFillColor = FWSunlit.Palette.backgroundDeep
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear
        triangularedView?.strokeWidth = 0
        triangularedView?.fwElevation = .raised1
        triangularedView?.fwInteractive = true

        imageWithTitleView?.titleColor = FWSunlit.Palette.textPrimary
        imageWithTitleView?.titleFont = .h6Title

        changesContentOpacityWhenHighlighted = true
    }

    /// Primary action: the emissive brand gradient with its own glow.
    func applyEnabledStyle() {
        fwStyleRole = .other
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = R.color.colorPink()!
        triangularedView?.highlightedFillColor = R.color.colorPink()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear
        triangularedView?.fwElevation = .emissive
        triangularedView?.fwInteractive = true

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = .h4Title

        changesContentOpacityWhenHighlighted = true
    }

    /// The neutral style. Screens use it both for secondary actions and for disabled primary actions, so the
    /// paint follows `isEnabled`: an enabled button is a Raised-2 secondary action, a disabled one sinks into
    /// an inset well with a dimmed title.
    func applyDisabledStyle() {
        fwStyleRole = .neutral
        triangularedView?.shadowOpacity = 0
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear
        triangularedView?.strokeWidth = 0
        triangularedView?.fwInteractive = true
        applyNeutralPaint()

        imageWithTitleView?.titleFont = .h4Title

        contentOpacityWhenDisabled = 1
    }

    func applyNeutralPaint() {
        triangularedView?.fillColor = isEnabled ? FWSunlit.Palette.background : FWSunlit.Palette.backgroundDeep
        triangularedView?.highlightedFillColor = FWSunlit.Palette.backgroundDeep
        triangularedView?.fwElevation = isEnabled ? .raised2 : .inset
        imageWithTitleView?.titleColor = isEnabled ? FWSunlit.Palette.textPrimary : FWSunlit.Palette.textTertiary
        if let wrappingLabel = wrappingLabel {
            wrappingLabel.textColor = imageWithTitleView?.titleColor
        }
    }

    func applyLoadingStyle() {
        fwStyleRole = .other
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = FWSunlit.Palette.backgroundDeep
        triangularedView?.highlightedFillColor = FWSunlit.Palette.backgroundDeep
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear
        triangularedView?.fwElevation = .inset
        triangularedView?.fwInteractive = true

        imageWithTitleView?.titleColor = .clear
        imageWithTitleView?.titleFont = .h4Title

        contentOpacityWhenDisabled = 1
    }

    func applyDestructiveStyle() {
        fwStyleRole = .other
        triangularedView?.shadowOpacity = 0
        triangularedView?.fillColor = FWSunlit.Palette.background
        triangularedView?.highlightedFillColor = FWSunlit.Palette.backgroundDeep
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear
        triangularedView?.strokeWidth = 0
        triangularedView?.fwElevation = .raised2
        triangularedView?.fwInteractive = true

        imageWithTitleView?.titleColor = R.color.colorRed()!
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }
}
