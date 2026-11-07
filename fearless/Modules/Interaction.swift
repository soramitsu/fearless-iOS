import Foundation
import UIKit

typealias InteractionDismissClosure = () -> Void

protocol Interaction: AnyObject {
    func addOnInteractionDismiss(closure: @escaping InteractionDismissClosure)
    func onInteractionDismiss()
}

extension Interaction where Self: UIViewController {
    func addOnInteractionDismiss(closure: @escaping InteractionDismissClosure) {
        onInteractionChanged = closure
    }

    func onInteractionDismiss() {
        onInteractionChanged?()
    }

    // MARK: - Private

    private var onInteractionChanged: InteractionDismissClosure? {
        get {
            let wrapper = objc_getAssociatedObject(self, &icAssociationKey) as? ClosureWrapper
            return wrapper?.closure
        }
        set(newValue) {
            objc_setAssociatedObject(
                self,
                &icAssociationKey,
                ClosureWrapper(newValue),
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }
}

extension UIViewController: Interaction {}

// Helpers

private var icAssociationKey: UInt8 = 0

private class ClosureWrapper {
    var closure: InteractionDismissClosure?

    init(_ closure: InteractionDismissClosure?) {
        self.closure = closure
    }
}
