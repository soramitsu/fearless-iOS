import UIKit
import FearlessFoundation

class ImportantFlowViewFactory {
    static func createNavigation(
        from rootViewController: UIViewController
    ) -> UINavigationController {
        ImportantFlowNavigationController(
            rootViewController: rootViewController,
            localizationManager: LocalizationManager.shared
        )
    }
}
