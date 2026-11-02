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

    /// UIKit includes the floating window controls and rounded corners in this
    /// region, keeping custom headers below them as the scene changes size.
    static func contentLayoutGuide(in view: UIView) -> UILayoutGuide {
        if #available(iOS 26.0, *), view.traitCollection.userInterfaceIdiom == .pad {
            return view.layoutGuide(for: .safeArea(cornerAdaptation: .vertical))
        }
        return view.safeAreaLayoutGuide
    }

    static func contentInsets(in view: UIView) -> UIEdgeInsets {
        if #available(iOS 26.0, *), view.traitCollection.userInterfaceIdiom == .pad {
            return view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
        }
        return view.safeAreaInsets
    }

    /// A pair of usable columns needs room for both controls and readable lists.
    /// Accessibility text stays stacked instead of compressing the two columns.
    static func showsColumns(in availableWidth: CGFloat, traits: UITraitCollection) -> Bool {
        isRegularWidth(traits) && availableWidth >= 820 &&
            !traits.preferredContentSizeCategory.isAccessibilityCategory
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

    /// A full-screen presentation outside any navigation stack (the PIN pad over the
    /// app, stories, startup recovery) centers its own content column. Call it from
    /// viewWillLayoutSubviews; screens in a navigation stack get the column from it.
    func applyAdaptiveContentColumnOutsideNavigation() {
        guard navigationController == nil, parent == nil else {
            return
        }
        applyAdaptiveContentColumn(
            containerWidth: view.bounds.width,
            containerSafeArea: view.window?.safeAreaInsets ?? .zero,
            traits: traitCollection
        )
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

/// Retains just the sheet's placement constraints so a live presentation can
/// switch between a centered card and a compact bottom sheet when resized.
final class AdaptiveSheetLayout {
    private weak var content: UIView?
    private weak var container: UIView?
    private var isCard: Bool?
    private var fillsHeight = false
    private var constraints: [NSLayoutConstraint] = []
    private var originalCornerRadius: CGFloat = 0
    private var originalCornerCurve: CALayerCornerCurve = .circular
    private var originalClipsToBounds = false

    /// `fillsHeight` is for sheets whose content scrolls and so has no height of its
    /// own: they reach from the top of the safe area, or fill a card's margins.
    func apply(to view: UIView, in container: UIView, fillsHeight: Bool = false) {
        let card = AdaptiveLayout.isRegularWidth(container.traitCollection)
        guard self.container !== container || content !== view || isCard != card ||
            self.fillsHeight != fillsHeight else { return }
        NSLayoutConstraint.deactivate(constraints)
        if content !== view {
            originalCornerRadius = view.layer.cornerRadius
            originalCornerCurve = view.layer.cornerCurve
            originalClipsToBounds = view.clipsToBounds
        }
        content = view
        self.container = container
        isCard = card
        self.fillsHeight = fillsHeight
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = card ? AdaptiveLayout.sheetCornerRadius : originalCornerRadius
        view.layer.cornerCurve = card ? .continuous : originalCornerCurve
        view.clipsToBounds = card || originalClipsToBounds
        let guide = AdaptiveLayout.contentLayoutGuide(in: container)
        if card {
            let margin = AdaptiveLayout.sheetMargin
            let center = view.centerYAnchor.constraint(equalTo: guide.centerYAnchor)
            center.priority = .defaultHigh
            let width = view.widthAnchor.constraint(equalToConstant: AdaptiveLayout.sheetWidth)
            width.priority = .defaultHigh
            constraints = [
                view.centerXAnchor.constraint(equalTo: guide.centerXAnchor), center, width,
                view.widthAnchor.constraint(lessThanOrEqualTo: guide.widthAnchor, constant: -2 * margin),
                fillsHeight
                    ? view.topAnchor.constraint(equalTo: guide.topAnchor, constant: margin)
                    : view.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: margin),
                fillsHeight
                    ? view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -margin)
                    : view.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -margin)
            ]
        } else {
            constraints = [
                view.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
                view.widthAnchor.constraint(equalTo: guide.widthAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                fillsHeight
                    ? view.topAnchor.constraint(equalTo: guide.topAnchor)
                    : view.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor)
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }
}

/// Places a screen's own bottom panel: its compact constraints on iPhone and in
/// compact iPad windows, a centered card in a regular-width iPad window.
final class AdaptivePanelPlacement {
    private let compact: [NSLayoutConstraint]
    private let card: [NSLayoutConstraint]
    private var isCard: Bool?

    init(panel: UIView, in view: UIView, compact: [NSLayoutConstraint]) {
        self.compact = compact
        let guide = view.safeAreaLayoutGuide
        let margin = AdaptiveLayout.sheetMargin
        let center = panel.centerYAnchor.constraint(equalTo: guide.centerYAnchor)
        center.priority = .defaultHigh
        let width = panel.widthAnchor.constraint(equalToConstant: AdaptiveLayout.sheetWidth)
        width.priority = .defaultHigh
        card = [
            panel.centerXAnchor.constraint(equalTo: guide.centerXAnchor), center, width,
            panel.widthAnchor.constraint(lessThanOrEqualTo: guide.widthAnchor, constant: -2 * margin),
            panel.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: margin),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -margin)
        ]
    }

    func update(for traits: UITraitCollection) {
        let showsCard = AdaptiveLayout.isRegularWidth(traits)
        guard showsCard != isCard else { return }
        isCard = showsCard
        NSLayoutConstraint.deactivate(showsCard ? compact : card)
        NSLayoutConstraint.activate(showsCard ? card : compact)
    }
}
