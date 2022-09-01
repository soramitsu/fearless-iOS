import Foundation
import UIKit

extension UIControl {
    func actionHandler(
        controlEvents control: UIControl.Event,
        forAction action: @escaping () -> Void
    ) {
        actionHandler(action: action)
        addTarget(self, action: #selector(triggerActionHandler), for: control)
    }

    private func actionHandler(action: (() -> Void)? = nil) {
        enum Action { static var action: (() -> Void)? }
        if action != nil {
            Action.action = action
        } else {
            Action.action?()
        }
    }

    @objc private func triggerActionHandler() {
        actionHandler()
    }
}
