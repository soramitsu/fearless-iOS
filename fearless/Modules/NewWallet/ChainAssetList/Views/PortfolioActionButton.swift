import UIKit

/// A multiline native control keeps the action readable at accessibility text sizes. Sun-lit surface
/// (redesign spec 2026-11-08): the primary action glows (emissive), the others are raised, a disabled action
/// sinks into an inset well, and a plain action is text only.
final class PortfolioActionButton: UIButton {
    enum Emphasis {
        case primary
        case secondary
        case plain
    }

    var emphasis: Emphasis = .secondary {
        didSet { applySurface() }
    }

    override var isEnabled: Bool {
        didSet { applySurface() }
    }

    private let surface: FWNeuView = {
        let view = FWNeuView()
        view.isUserInteractionEnabled = false
        view.isInteractive = true
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: min(FWSunlit.Radius.button, $0.height / 2)) }
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        var config = UIButton.Configuration.plain()
        config.background.backgroundColor = .clear
        config.background.cornerRadius = 0
        config.baseForegroundColor = FWSunlit.Palette.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        config.titleLineBreakMode = .byWordWrapping
        config.titleAlignment = .center
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak self] attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: self?.traitCollection)
            return attributes
        }
        configuration = config
        titleLabel?.numberOfLines = 0
        titleLabel?.adjustsFontForContentSizeCategory = true
        insertSubview(surface, at: 0)
        addTarget(self, action: #selector(pressDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(pressUp), for: FWPress.releaseEvents)
        applySurface()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitPreferredContentSizeCategory
                    .self]) { (button: PortfolioActionButton, _: UITraitCollection) in
                button.setNeedsUpdateConfiguration()
                button.invalidateIntrinsicContentSize()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.frame = bounds
        sendSubviewToBack(surface)
        surface.sunRim = FWSunAnchor.shared.sunRim(for: surface, fallback: FWRowSunlit.fallbackRim)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            setNeedsUpdateConfiguration()
            invalidateIntrinsicContentSize()
        }
    }

    func set(loading: Bool) {
        configuration?.showsActivityIndicator = loading
        isEnabled = !loading
    }

    private func applySurface() {
        surface.isHidden = emphasis == .plain
        switch (emphasis, isEnabled) {
        case (.plain, _):
            break
        case (_, false):
            surface.style = .inset
        case (.primary, true):
            surface.style = .emissive
        case (.secondary, true):
            surface.style = .raised1
        }
    }

    @objc private func pressDown() {
        FWPress.apply(true, to: self, surface: emphasis == .plain ? nil : surface)
    }

    @objc private func pressUp() {
        FWPress.apply(false, to: self, surface: emphasis == .plain ? nil : surface)
    }
}
