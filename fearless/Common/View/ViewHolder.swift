import UIKit

protocol ViewHolder: AnyObject {
    associatedtype RootViewType: UIView
}

extension ViewHolder where Self: UIViewController {
    var rootView: RootViewType {
        guard let rootView = view as? RootViewType else {
            fatalError("Excpected \(RootViewType.description()) as rootView. Now \(type(of: view))")
        }
        return rootView
    }
}
