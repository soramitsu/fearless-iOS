import UIKit

/// Applies adaptive presentation to the existing export views and action controls.
final class ExportGenericAdaptiveLayout {
    let headingLabel = UILabel()
    private let root: UIView
    private let container: ScrollableContainerView
    private let buttons: UIStackView
    private let expandable: ExpandableActionControl
    private let expansionHeight: NSLayoutConstraint

    init(root: UIView, container: ScrollableContainerView, buttons: UIStackView, expandable: ExpandableActionControl) {
        self.root = root
        self.container = container
        self.buttons = buttons
        self.expandable = expandable
        headingLabel.numberOfLines = 0
        headingLabel.textColor = R.color.colorWhite()
        headingLabel.accessibilityTraits.insert(.header)
        container.stackView.insertArrangedSubview(headingLabel, at: 0)
        headingLabel.widthAnchor.constraint(
            equalTo: root.safeAreaLayoutGuide.widthAnchor, constant: -2 * UIConstants.horizontalInset
        ).isActive = true
        expandable.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil }
            .forEach { $0.isActive = false }
        expansionHeight = expandable.heightAnchor.constraint(equalToConstant: 56)
        expansionHeight.isActive = true
        expandable.titleLabel.numberOfLines = 0
    }

    func refresh(title: String?, locale: Locale, traits: UITraitCollection) {
        headingLabel.text = title
        headingLabel.font = .fw(.titleL, locale: locale, compatibleWith: traits)
        expandable.titleLabel.font = .fw(.labelL, locale: locale, compatibleWith: traits)
        for view in descendants(root) {
            if let details = view as? DetailsTriangularedView {
                details.configureWrapping(locale: locale, compatibleWith: traits)
            } else if let mnemonic = view as? TitledMnemonicView {
                mnemonic.configureWrapping(locale: locale, compatibleWith: traits)
            } else if let multiline = view as? MultilineTriangularedView {
                multiline.configureWrapping(locale: locale, compatibleWith: traits)
            } else if let button = view as? TriangularedButton {
                if button.wrappingLabel == nil {
                    button.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil }
                        .forEach { $0.isActive = false }
                }
                button.configureWrappingTitle(locale: locale, compatibleWith: traits)
            }
        }
        if container.stackView.arrangedSubviews.last !== buttons {
            container.stackView.removeArrangedSubview(buttons)
            container.stackView.addArrangedSubview(buttons)
        }
        updateWidth()
    }

    func updateWidth() {
        let width = max(
            1,
            root.bounds.inset(by: root.safeAreaInsets).width - 2 * UIConstants.horizontalInset
                - expandable.contentInsets.left - expandable.contentInsets.right
                - expandable.horizontalSpacing - (expandable.indicator?.intrinsicContentSize.width ?? 0)
        )
        if expandable.titleLabel.preferredMaxLayoutWidth != width {
            expandable.titleLabel.preferredMaxLayoutWidth = width
            expandable.invalidateLayout()
        }
        let height = ceil(expandable.titleLabel.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height) + 24
        if expansionHeight.constant != max(56, height) {
            expansionHeight.constant = max(56, height)
            expandable.invalidateLayout()
        }
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }
}
