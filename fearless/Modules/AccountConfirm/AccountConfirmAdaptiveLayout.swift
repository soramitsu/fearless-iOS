import UIKit
import SoraUI

/// Rearranges the existing XIB controls without changing their targets or confirmation state.
final class AccountConfirmAdaptiveLayout {
    let headingLabel = UILabel()
    private var nextTop: NSLayoutConstraint?

    init(
        root: UIView,
        scroll: UIScrollView,
        content: UIView,
        top: UIView,
        bottom: UIView,
        actions: UIView,
        next: TriangularedButton,
        actionsHeight: NSLayoutConstraint
    ) {
        actionsHeight.isActive = false
        next.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil }
            .forEach { $0.isActive = false }
        content.constraints.filter {
            ($0.firstItem as? UIView === top && $0.firstAttribute == .top) ||
                ($0.firstItem as? UIView === content && $0.firstAttribute == .bottom)
        }.forEach { $0.isActive = false }
        actions.removeFromSuperview()
        content.addSubview(actions)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.numberOfLines = 0
        headingLabel.textColor = R.color.colorWhite()
        headingLabel.accessibilityTraits.insert(.header)
        content.addSubview(headingLabel)
        let nextTop = next.topAnchor.constraint(equalTo: actions.topAnchor)
        self.nextTop = nextTop
        NSLayoutConstraint.activate([
            scroll.bottomAnchor.constraint(equalTo: root.safeAreaLayoutGuide.bottomAnchor),
            headingLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            headingLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            headingLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            top.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 16),
            actions.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            actions.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            actions.topAnchor.constraint(equalTo: bottom.bottomAnchor, constant: 24),
            content.bottomAnchor.constraint(equalTo: actions.bottomAnchor, constant: 24),
            nextTop
        ])
    }

    func addSkip(_ skip: TriangularedButton, to actions: UIView, above next: TriangularedButton) {
        nextTop?.isActive = false
        NSLayoutConstraint.activate([
            skip.leadingAnchor.constraint(equalTo: actions.leadingAnchor),
            skip.trailingAnchor.constraint(equalTo: actions.trailingAnchor),
            skip.topAnchor.constraint(equalTo: actions.topAnchor),
            next.topAnchor.constraint(equalTo: skip.bottomAnchor, constant: UIConstants.mainAccessoryActionsSpacing)
        ])
    }

    func refresh(
        title: String?,
        details: UILabel,
        actions: [TriangularedButton],
        locale: Locale,
        traits: UITraitCollection
    ) {
        headingLabel.text = title
        headingLabel.font = .fw(.titleL, locale: locale, compatibleWith: traits)
        details.font = .fw(.bodyL, locale: locale, compatibleWith: traits)
        actions.forEach { $0.configureWrappingTitle(locale: locale, compatibleWith: traits) }
    }
}

/// A measured label over the existing RoundedButton retains the original target and title value.
final class AccountConfirmWordButton: RoundedButton {
    private let wordLabel = UILabel()
    var maximumWidth: CGFloat = .greatestFiniteMagnitude {
        didSet { if maximumWidth != oldValue { invalidateLayout() } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWordLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWordLabel()
    }

    private func setupWordLabel() {
        wordLabel.numberOfLines = 0
        wordLabel.lineBreakMode = .byCharWrapping
        wordLabel.textAlignment = .center
        wordLabel.isUserInteractionEnabled = false
        wordLabel.isAccessibilityElement = false
        addSubview(wordLabel)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    func refresh(locale: Locale, traits: UITraitCollection, adaptiveFont: Bool = true) {
        let font = adaptiveFont ? UIFont.fw(.phraseWord, locale: locale, compatibleWith: traits)
            : .legacySora(size: 14, weight: .regular, textStyle: .callout, compatibleWith: traits)
        imageWithTitleView?.titleFont = font
        wordLabel.font = font
        wordLabel.text = imageWithTitleView?.title
        wordLabel.textColor = imageWithTitleView?.titleColor
        accessibilityLabel = wordLabel.text
        imageWithTitleView?.isHidden = true
        invalidateLayout()
    }

    override var intrinsicContentSize: CGSize {
        let horizontalInsets = contentInsets.left + contentInsets.right
        let width = min(maximumWidth, max(44, ceil(wordLabel.intrinsicContentSize.width) + horizontalInsets))
        let fitting = wordLabel.sizeThatFits(CGSize(
            width: max(1, width - horizontalInsets),
            height: .greatestFiniteMagnitude
        ))
        return CGSize(width: width, height: max(44, ceil(fitting.height) + contentInsets.top + contentInsets.bottom))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageWithTitleView?.isHidden = true
        wordLabel.frame = bounds.inset(by: contentInsets)
        wordLabel.alpha = contentView?.alpha ?? 1
    }

    override func accessibilityActivate() -> Bool {
        guard isEnabled, isUserInteractionEnabled, !isHidden else { return false }
        sendActions(for: .touchUpInside)
        return true
    }
}
