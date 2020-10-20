import Foundation
import SoraUI

final class ShakeAnimator: ViewAnimatorProtocol {
    let duration: TimeInterval
    let delay: TimeInterval
    let dumpingFactor: CGFloat
    let initialVelocity: CGFloat
    let initialAmplitude: CGFloat
    let options: UIView.AnimationOptions

    init(duration: TimeInterval = 0.25,
         delay: TimeInterval = 0.0,
         dumpingFactor: CGFloat = 0.4,
         initialVelocity: CGFloat = 1.0,
         initialAmplitude: CGFloat = 20.0,
         options: UIView.AnimationOptions = []) {
        self.duration = duration
        self.delay = delay
        self.dumpingFactor = dumpingFactor
        self.initialVelocity = initialVelocity
        self.initialAmplitude = initialAmplitude
        self.options = options
    }

    func animate(view: UIView, completionBlock: ((Bool) -> Void)?) {
        view.transform = CGAffineTransform(translationX: initialAmplitude, y: 0)

        let block = {
            view.transform = CGAffineTransform.identity
        }

        UIView.animate(withDuration: duration,
                       delay: delay,
                       usingSpringWithDamping: dumpingFactor,
                       initialSpringVelocity: initialVelocity,
                       options: options,
                       animations: block,
                       completion: completionBlock)
    }
}
