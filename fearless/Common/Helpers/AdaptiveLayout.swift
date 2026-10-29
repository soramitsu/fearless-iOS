import UIKit

/// Layout rules for iPad windows with a regular horizontal size class. In compact
/// width (iPhone, Slide Over, a narrow split view or Stage Manager window) every
/// rule resolves to the iPhone layout.
enum AdaptiveLayout {
    /// Widest content column for phone-designed screens in a regular-width window.
    static let contentColumnWidth: CGFloat = 720
    /// Width of sheets and alert cards presented over a regular-width window.
    static let sheetWidth: CGFloat = 560
    /// Space kept between a centered sheet and the window's safe area.
    static let sheetMargin: CGFloat = 24
    /// Corner radius of a sheet shown as a centered card.
    static let sheetCornerRadius: CGFloat = 24

    static func isRegularWidth(_ traits: UITraitCollection) -> Bool {
        traits.userInterfaceIdiom == .pad && traits.horizontalSizeClass == .regular
    }

    /// Inset on each side that centers a column of at most `maxWidth` points in a
    /// container `containerWidth` points wide. Zero when the column already fits.
    static func columnInset(containerWidth: CGFloat, maxWidth: CGFloat = contentColumnWidth) -> CGFloat {
        guard containerWidth > maxWidth else {
            return 0
        }
        return ((containerWidth - maxWidth) / 2).rounded(.down)
    }

    /// Width of a centered sheet card in a container `containerWidth` points wide.
    static func sheetCardWidth(containerWidth: CGFloat) -> CGFloat {
        min(sheetWidth, max(0, containerWidth - 2 * sheetMargin))
    }
}

/// A screen that lays out its own wide iPad design and keeps the full width of
/// its container instead of the centered content column.
protocol AdaptiveFullWidthContent: AnyObject {}

extension UIViewController {
    /// Centers this screen's safe area in a readable column when it is shown in a
    /// regular-width iPad window, and restores the full width otherwise. Only the
    /// horizontal additional safe area insets are changed.
    func applyAdaptiveContentColumn(
        containerWidth: CGFloat,
        containerSafeArea: UIEdgeInsets,
        traits: UITraitCollection
    ) {
        var inset: CGFloat = 0
        if AdaptiveLayout.isRegularWidth(traits), !(self is AdaptiveFullWidthContent) {
            let availableWidth = containerWidth - containerSafeArea.left - containerSafeArea.right
            inset = AdaptiveLayout.columnInset(containerWidth: availableWidth)
        }

        guard additionalSafeAreaInsets.left != inset || additionalSafeAreaInsets.right != inset else {
            return
        }
        additionalSafeAreaInsets.left = inset
        additionalSafeAreaInsets.right = inset
    }

    /// Gives an action sheet or share sheet the anchor UIKit requires on iPad, where
    /// presenting an unanchored popover raises an exception. The popover points at
    /// the control the user last touched, or floats in the middle of this screen.
    /// iPhone presentation is unchanged.
    func anchorPopover(of controller: UIViewController) {
        guard
            let popover = controller.popoverPresentationController,
            popover.sourceView == nil,
            popover.barButtonItem == nil,
            let hostView = viewIfLoaded
        else {
            return
        }
        if #available(iOS 16.0, *), popover.sourceItem != nil {
            return
        }

        if
            let touchedView = (hostView.window as? FearlessWindow)?.lastTouchedView,
            touchedView.window === hostView.window,
            !touchedView.bounds.isEmpty {
            popover.sourceView = touchedView
            popover.sourceRect = touchedView.bounds
        } else {
            popover.sourceView = hostView
            popover.sourceRect = CGRect(x: hostView.bounds.midX, y: hostView.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
    }
}
