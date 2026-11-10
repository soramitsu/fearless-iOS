import UIKit

/// A sun-lit neumorphic surface (spec section 3): Raised-1, Raised-2, Inset or Emissive, lit by the key light
/// from the top-left, with a rim that catches the sun bounce. Calm and Reduced effects drop the shadows,
/// High contrast swaps them for a solid stroke. Geometry never depends on the paint.
final class FWNeuView: UIView {
    enum Style {
        /// Raised-2: cards, round action buttons, the tab bar.
        case raised
        /// Raised-1: list rows and chips.
        case raised1
        /// Inputs, wells and the selected tab.
        case inset
        /// Primary actions and the sun: brand gradient with its own glow.
        case emissive
        /// No light of its own; keeps the rim of an interactive control.
        case flat

        var elevation: FWSunlit.Elevation {
            switch self {
            case .raised: return .raised2
            case .raised1: return .raised1
            case .inset: return .inset
            case .emissive: return .emissive
            case .flat: return .flat
            }
        }
    }

    var style: Style = .raised {
        didSet { applyStyle() }
    }

    var calm = false {
        didSet { applyStyle() }
    }

    var controlFocused = false {
        didSet { applyStyle() }
    }

    var hasError = false {
        didSet { applyStyle() }
    }

    /// Interactive controls keep a 1 pt rim in every mode.
    var isInteractive = false {
        didSet { applyStyle() }
    }

    /// Sun bounce on the top rim, from `FWSunlit.Light.sunRim`.
    var sunRim: CGFloat = 0 {
        didSet { applyStyle() }
    }

    /// Overrides the surface colour (`bg`, or `bgDeep` for inset).
    var surfaceColor: UIColor? {
        didSet { applyStyle() }
    }

    var shape: (CGRect) -> UIBezierPath = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.button) } {
        didSet { setNeedsLayout() }
    }

    private(set) var isPressed = false
    private let effects: FWEffects
    private var observation: NSObjectProtocol?
    private let painter = FWSurfacePainter()

    init(frame: CGRect = .zero, effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false
        painter.install(in: layer)
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.applyStyle() }
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observation {
            effects.notificationCenter.removeObserver(observation)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        painter.layout(path: shape(bounds), bounds: bounds)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyStyle()
    }

    /// Raised to inset and back (spec section 4: 90 ms in, 160 ms out). The host scales the control.
    func setPressed(_ pressed: Bool, animated: Bool) {
        guard pressed != isPressed else { return }
        isPressed = pressed
        let policy = FWMotionPolicy.current(effects: effects, calm: calm)
        let style = policy.style(for: .press)
        let duration = animated && style.animates ? (pressed ? style.duration : FWSunlit.Motion.pressOut) : 0
        painter.apply(currentState(), duration: duration)
    }

    private func currentState() -> FWSurfacePainter.State {
        let contrast = effects.highContrast || traitCollection.accessibilityContrast == .high
        return FWSurfacePainter.State(
            elevation: style.elevation,
            fill: surfaceColor,
            sunRim: sunRim,
            pressed: isPressed,
            focused: controlFocused,
            error: hasError,
            interactive: isInteractive || controlFocused || hasError,
            reduced: effects.paintReduced(calm: calm),
            highContrast: contrast
        )
    }

    private func applyStyle() {
        painter.apply(currentState())
    }
}
