import UIKit

enum RetainedDataRestoreAssembly {
    static func createView() -> UIViewController {
        RetainedDataRestoreViewController(interactor: RetainedDataRestoreInteractor.shared)
    }
}
