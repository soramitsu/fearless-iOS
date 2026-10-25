import Foundation

public final class WeakWrapper {
    public weak var target: AnyObject?

    public init(target: AnyObject) {
        self.target = target
    }
}
