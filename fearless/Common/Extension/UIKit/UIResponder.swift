import UIKit

extension UIResponder {
    /**
     * Returns the next responder in the responder chain cast to the given type, or
     * if nil, recurses the chain until the next responder is nil or castable.
     */
    func next<U: UIResponder>(of _: U.Type = U.self) -> U? {
        next.flatMap { $0 as? U ?? $0.next() }
    }
}
