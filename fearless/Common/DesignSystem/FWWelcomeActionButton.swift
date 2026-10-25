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
        fill.startPoint = CGPoint(x: 0.5, y: 0)
        fill.endPoint = CGPoint(x: 0.5, y: 1)
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

    override var isHighlighted: Bool { didSet { setNeedsLayout() } }

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
        let path = FWChamferPath.path(in: bounds)
        fill.frame = bounds
        fillMask.path = path.cgPath
        let colors: [UIColor]
        switch style {
        case .primary: colors = FWTokens.Gradients.primaryFill.colors
        case .secondary: colors = [R.color.fwSurfaceRaised() ?? .black, R.color.fwSurfaceRaised() ?? .black]
        case .link: colors = [.clear, .clear]
        }
        fill.colors = colors.map { $0.resolvedColor(with: traitCollection).cgColor }
        fill.opacity = isHighlighted ? 0.75 : 1
        label.textColor = style == .primary ? R.color.fwTextOnAccent() : R.color.fwTextPrimary()
        let normalStroke = style == .primary ? R.color.fwAccentEdge() : R.color.fwStrokeControl()
        let stroke = isFocused ? R.color.fwFocus() : normalStroke
        let inset: CGFloat = isFocused ? -2 : 0.5
        rim.path = FWChamferPath.path(in: bounds.insetBy(dx: inset, dy: inset)).cgPath
        rim.lineWidth = isFocused ? 2 : 1
        let rimColor = style == .link && !isFocused ? UIColor.clear : stroke
        rim.strokeColor = rimColor?.resolvedColor(with: traitCollection).cgColor
        CATransaction.commit()
        FWGlow.apply(to: self, halo: halo, path: path, enabled: style == .primary && !isHighlighted, effects: effects)
    }
}
