import UIKit

/// Chrome only: Full uses platform material under an 88% tint; all other modes avoid live blur.
final class FWChromeBackgroundView: UIView {
    var calm = false {
        didSet { applyStyle() }
    }

    private let effects: FWEffects
    private let tint = UIView()
    private var material: UIVisualEffectView?
    private var observation: NSObjectProtocol?

    init(frame: CGRect = .zero, effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        tint.isUserInteractionEnabled = false
        tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
        material?.frame = bounds
        tint.frame = material?.contentView.bounds ?? bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyStyle()
    }

    private func applyStyle() {
        let reduced = effects.paintReduced(calm: calm) || traitCollection.accessibilityContrast == .high
        let live = effects.allowsLiveBlur(calm: calm) && !reduced
        if live, material == nil {
            let effect: UIVisualEffect
            if #available(iOS 26.0, *) {
                effect = UIGlassEffect()
            } else {
                effect = UIBlurEffect(style: .systemThinMaterialDark)
            }
            let view = UIVisualEffectView(effect: effect)
            view.isUserInteractionEnabled = false
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(view)
            view.contentView.addSubview(tint)
            material = view
        } else if !live {
            material?.removeFromSuperview()
            material = nil
            addSubview(tint)
        }
        tint.backgroundColor = reduced ? R.color.fwSurfaceRaised() :
            (live ? R.color.fwSurfaceChrome() : R.color.fwSurfaceChromeSolid())
        setNeedsLayout()
    }
}
