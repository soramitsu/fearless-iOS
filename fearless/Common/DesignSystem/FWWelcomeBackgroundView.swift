import UIKit

/// Static page paint. Accessibility and power preferences never change the content or routes.
final class FWWelcomeBackgroundView: UIView {
    private struct Blob {
        let color: UIColor
        let alpha: CGFloat
        let center: CGPoint
        let radius: CGFloat
    }

    private let effects: FWEffects
    private var observation: NSObjectProtocol?

    init(effects: FWEffects) {
        self.effects = effects
        super.init(frame: .zero)
        backgroundColor = R.color.fwBgBase()
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        contentMode = .redraw
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.setNeedsDisplay() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard !effects.paintReduced(), traitCollection.accessibilityContrast != .high,
              let context = UIGraphicsGetCurrentContext() else { return }
        let colors = FWTokens.Gradients.accent.colors
        let blobs = [
            Blob(color: colors[0], alpha: 0.18, center: CGPoint(x: 0.15, y: 0.12), radius: 0.55),
            Blob(color: colors[2], alpha: 0.12, center: CGPoint(x: 0.95, y: 0.08), radius: 0.45),
            Blob(color: colors[1], alpha: 0.16, center: CGPoint(x: 0.5, y: 1), radius: 0.60)
        ]
        for blob in blobs {
            let stops = [blob.color.withAlphaComponent(blob.alpha).cgColor, blob.color.withAlphaComponent(0).cgColor]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops as CFArray, locations: [0, 1]
            ) else { continue }
            let center = CGPoint(x: bounds.width * blob.center.x, y: bounds.height * blob.center.y)
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: bounds.width * blob.radius,
                options: []
            )
        }
    }
}
