import UIKit

protocol ControllerBackedProtocol: AnyObject {
    var isSetup: Bool { get }
    var controller: UIViewController { get }
}

extension ControllerBackedProtocol where Self: UIViewController {
    var isSetup: Bool {
        controller.isViewLoaded
    }

    var controller: UIViewController {
        self
    }
}
