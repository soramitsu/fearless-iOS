import UIKit

public final class CustomVisualEffectView: UIVisualEffectView {

    public init(effect: UIVisualEffect, intensity: CGFloat) {
        theEffect = effect
        customIntensity = intensity
        super.init(effect: nil)
    }

    public required init?(coder aDecoder: NSCoder) { nil }

    deinit {
        animator?.stopAnimation(true)
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        effect = nil
        animator?.stopAnimation(true)
        animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [unowned self] in
            self.effect = theEffect
        }
        animator?.fractionComplete = customIntensity
    }

    private let theEffect: UIVisualEffect
    private let customIntensity: CGFloat
    private var animator: UIViewPropertyAnimator?
}
