import UIKit

enum AccountManagementViewFactory {
    static func createViewForSwitch() -> ControllerBackedProtocol? {
        // Minimal placeholder controller to satisfy build in test configuration
        PlaceholderAccountManagementController()
    }
}

final class PlaceholderAccountManagementController: UIViewController {}
