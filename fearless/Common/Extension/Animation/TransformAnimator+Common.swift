import UIKit
import SoraUI

extension TransformAnimator {
    static var highlightedOn: TransformAnimator {
        return TransformAnimator(from: CGAffineTransform.identity,
                                 to: CGAffineTransform(scaleX: 0.95, y: 0.95),
                                 duration: 0.1)
    }

    static var highlightedOff: TransformAnimator {
        return TransformAnimator(from: CGAffineTransform(scaleX: 0.95, y: 0.95),
                                 to: CGAffineTransform.identity,
                                 duration: 0.2)
    }
}
