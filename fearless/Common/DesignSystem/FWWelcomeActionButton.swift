import UIKit

/// Native button input with a wrapping label and a content-driven height.
final class FWWelcomeActionButton: UIButton {
    enum Style { case primary, secondary, link }

    let label = UILabel()
    private let style: Style
    private let effects: FWEffects
    private var locale = Locale.current
    private var observation: NSObjectProtocol?
    private let fill = CAGradientLayer()
    private let fillMask = CAShapeLayer()
    private let rim = CAShapeLayer()
    private let halo = CALayer()
    /// Secondary actions are Raised-2 surfaces lit from the top-left (sun-lit redesign).
    private var surface: FWNeuView?

    init(style: Style, effects: FWEffects) {
        self.style = style
        self.effects = effects
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = style == .link ? [.button, .link] : .button
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.isAccessibilityElement = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        layer.insertSublayer(fill, at: 0)
        fill.mask = fillMask
        fill.startPoint = .zero
        fill.endPoint = CGPoint(x: 1, y: 1)
        if style == .secondary {
            let surface = FWNeuView(effects: effects)
            surface.style = .raised
            surface.isInteractive = true
            surface.isUserInteractionEnabled = false
            surface.shape = { UIBezierPath(roundedRect: $0, cornerRadius: min(FWSunlit.Radius.button, $0.height / 2)) }
            insertSubview(surface, at: 0)
            surface.snp.makeConstraints { $0.edges.equalToSuperview() }
            self.surface = surface
        }
        layer.addSublayer(rim)
        rim.fillColor = nil
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        }
        snp.makeConstraints { $0.height.greaterThanOrEqualTo(style == .link ? 48 : 56) }
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.setNeedsLayout() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
        halo.removeFromSuperlayer()
    }

    func configure(title: String, locale: Locale) {
        self.locale = locale
        label.text = title
        accessibilityLabel = title
        applyTypography()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            applyTypography()
        }
        setNeedsLayout()
    }

    private func applyTypography() {
        let role: FWFontStyle = style == .link ? .bodyS : .labelL
        let font = UIFont.fw(role, locale: locale, compatibleWith: traitCollection)
        label.font = font
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = UIFont.fwLineHeight(role, locale: locale, compatibleWith: traitCollection)
        label.attributedText = NSAttributedString(string: label.text ?? "", attributes: [
            .font: font, .paragraphStyle: paragraph,
            .underlineStyle: style == .link ? NSUnderlineStyle.single.rawValue : 0
        ])
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var isHighlighted: Bool {
        didSet {
            setNeedsLayout()
            guard isHighlighted != oldValue, style != .link else { return }
            FWPress.apply(isHighlighted, to: self, surface: surface, effects: effects)
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        halo.removeFromSuperlayer()
        superview?.layer.insertSublayer(halo, at: 0)
        setNeedsLayout()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = min(FWSunlit.Radius.button, bounds.height / 2)
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        fill.frame = bounds
        fillMask.path = path.cgPath
        let colors: [UIColor]
        switch style {
        case .primary: colors = [FWSunlit.Palette.gradientStart, FWSunlit.Palette.gradientEnd]
        case .secondary, .link: colors = [.clear, .clear]
        }
        fill.colors = colors.map(\.cgColor)
        fill.opacity = isHighlighted ? 0.86 : 1
        label.textColor = style == .primary ? .white : FWSunlit.Palette.textPrimary
        // Primary: the 1 pt top highlight of an emissive surface; secondary rims come from its surface.
        let normalStroke: UIColor = style == .primary
            ? UIColor(white: 1, alpha: FWSunlit.Rim.emissiveHighlightAlpha / 2) : .clear
        let stroke = isFocused ? FWSunlit.Palette.brand : normalStroke
        let inset: CGFloat = isFocused ? -2 : 0.5
        rim.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset), cornerRadius: max(0, radius - inset)
        ).cgPath
        rim.lineWidth = isFocused ? 2 : 1
        let rimColor = style == .link && !isFocused ? UIColor.clear : stroke
        rim.strokeColor = rimColor.cgColor
        CATransaction.commit()
        FWGlow.apply(to: self, halo: halo, path: path, enabled: style == .primary && !isHighlighted, effects: effects)
    }
}
