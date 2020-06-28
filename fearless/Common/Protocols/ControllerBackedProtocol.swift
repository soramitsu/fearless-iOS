import UIKit

protocol ControllerBackedProtocol: class {
    var isSetup: Bool { get }
    var controller: UIViewController { get }
}

extension ControllerBackedProtocol where Self: UIViewController {
    var isSetup: Bool {
        return controller.isViewLoaded
    }

    var controller: UIViewController {
        return self
    }
}
