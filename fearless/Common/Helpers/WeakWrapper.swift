import Foundation

final class WeakWrapper {
    weak var target: AnyObject?

    init(target: AnyObject) {
        self.target = target
    }
}
