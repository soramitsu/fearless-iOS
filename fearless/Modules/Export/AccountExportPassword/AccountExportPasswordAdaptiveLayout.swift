import UIKit
import SoraUI

/// Keeps the existing XIB controls, targets and secure editors inside one scrolling surface.
final class AccountExportPasswordAdaptiveLayout {
    let headingLabel = UILabel()
    private let errorLabel = UILabel()
    private let errorStack = UIStackView()
    private let fields: [AccountExportPasswordField]
    private let hint: UILabel
    private var actionBelowFields: NSLayoutConstraint?
    private var actionBelowError: NSLayoutConstraint?

    init(
        root: UIView,
        scroll: UIScrollView,
        content: UIView,
        source: BorderedSubtitleActionView,
        hint: UILabel,
        fields: [AccountExportPasswordField],
        action: TriangularedButton,
        contentBottom: NSLayoutConstraint
    ) {
        self.fields = fields
        self.hint = hint
        contentBottom.isActive = false
        action.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil }
            .forEach { $0.isActive = false }
        content.constraints.filter { $0.firstItem as? UIView === source && $0.firstAttribute == .top }
            .forEach { $0.isActive = false }
        fields.forEach { field in
            field.superview?.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil }
                .forEach { $0.isActive = false }
        }
        action.removeFromSuperview()
        content.addSubview(action)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.numberOfLines = 0
        headingLabel.textColor = R.color.colorWhite()
        headingLabel.accessibilityTraits.insert(.header)
        content.addSubview(headingLabel)
        errorLabel.numberOfLines = 0
        errorLabel.textColor = R.color.colorWhite()
        let icon = UIImageView(image: R.image.iconError())
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        errorStack.axis = .horizontal
        errorStack.alignment = .top
        errorStack.spacing = 8
        errorStack.addArrangedSubview(icon)
        errorStack.addArrangedSubview(errorLabel)
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(errorStack)
        guard let last = fields.last?.superview else { return }
        actionBelowFields = action.topAnchor.constraint(equalTo: last.bottomAnchor, constant: 24)
        actionBelowError = action.topAnchor.constraint(equalTo: errorStack.bottomAnchor, constant: 24)
        NSLayoutConstraint.activate([
            scroll.bottomAnchor.constraint(equalTo: root.safeAreaLayoutGuide.bottomAnchor),
            headingLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            headingLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            headingLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            source.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 24),
            errorStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            errorStack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            errorStack.topAnchor.constraint(equalTo: last.bottomAnchor, constant: 16),
            action.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            action.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: action.bottomAnchor, constant: 24)
        ])
        setError(nil)
    }

    func refresh(
        title: String?,
        source: BorderedSubtitleActionView,
        action: TriangularedButton,
        locale: Locale,
        traits: UITraitCollection
    ) {
        headingLabel.text = title
        headingLabel.font = .fw(.titleL, locale: locale, compatibleWith: traits)
        hint.font = .fw(.bodyL, locale: locale, compatibleWith: traits)
        source.configureWrapping(locale: locale, compatibleWith: traits)
        action.configureWrappingTitle(locale: locale, compatibleWith: traits)
        errorLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        fields.forEach { $0.configure(locale: locale, traits: traits) }
    }

    func setError(_ message: String?) {
        errorLabel.text = message
        errorStack.isHidden = message == nil
        actionBelowFields?.isActive = message == nil
        actionBelowError?.isActive = message != nil
    }
}

/// Opt-in caption layout preserves SoraUI's native text field, delegates and secure-entry state.
final class AccountExportPasswordField: AnimatedTextField {
    private let caption = UILabel()
    private var adaptive = false
    private var measuredWidth: CGFloat = 0

    override var title: String? {
        get { adaptive ? caption.text : super.title }
        set {
            if adaptive { caption.text = newValue; invalidateIntrinsicContentSize() } else { super.title = newValue }
            textField?.accessibilityLabel = newValue
        }
    }

    func configure(locale: Locale, traits: UITraitCollection) {
        if !adaptive {
            caption.text = super.title
            super.title = nil
            adaptive = true
            caption.numberOfLines = 0
            caption.isAccessibilityElement = false
            caption.textColor = placeholderColor
            addSubview(caption)
        }
        caption.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        textFont = .fw(.bodyL, locale: locale, compatibleWith: traits)
        textField.accessibilityLabel = caption.text
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        guard adaptive else { return super.intrinsicContentSize }
        let fitting = caption.sizeThatFits(CGSize(width: max(1, bounds.width - 32), height: .greatestFiniteMagnitude))
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: 16 + ceil(fitting.height) + 8 + max(44, ceil(textFont?.lineHeight ?? 0)) + 16
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard adaptive else { return }
        if measuredWidth != bounds.width {
            measuredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
        let width = max(1, bounds.width - 32)
        let height = ceil(caption.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        caption.frame = CGRect(x: 16, y: 16, width: width, height: height)
        textField.isHidden = false
        textField.frame = CGRect(
            x: 16,
            y: caption.frame.maxY + 8,
            width: width,
            height: max(44, ceil(textFont?.lineHeight ?? 0))
        )
        textField.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(textField.bounds, in: textField)
    }
}
