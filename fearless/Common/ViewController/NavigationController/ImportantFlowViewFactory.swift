import UIKit
import SoraFoundation

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
