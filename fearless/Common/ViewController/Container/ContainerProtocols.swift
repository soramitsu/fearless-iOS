import UIKit

protocol Reloadable: AnyObject {
    var reloadableDelegate: ReloadableDelegate? { get set }

    func reload()
}

protocol ReloadableDelegate: AnyObject {
    func didInitiateReload(on reloadable: Reloadable)
}

@objc protocol ContainableObserver {
    func willChangePreferredContentHeight()
    func didChangePreferredContentHeight(to newContentHeight: CGFloat)
}

protocol Containable: AnyObject {
    var contentView: UIView { get }
    var contentInsets: UIEdgeInsets { get }
    var preferredContentHeight: CGFloat { get }
    var observable: ViewModelObserverContainer<ContainableObserver> { get }
    func setContentInsets(_ contentInsets: UIEdgeInsets, animated: Bool)
}

enum DraggableState {
    case compact
    case full

    var other: DraggableState {
        switch self {
        case .compact:
            return .full
        case .full:
            return .compact
        }
    }
}

protocol DraggableDelegate: AnyObject {
    var presentationNavigationItem: UINavigationItem? { get }

    func wantsTransit(to draggableState: DraggableState, animating: Bool)
}

protocol Draggable: AnyObject {
    var draggableView: UIView { get }

    var delegate: DraggableDelegate? { get set }

    var scrollPanRecognizer: UIPanGestureRecognizer? { get }

    func set(dragableState: DraggableState, animated: Bool)
    func set(contentInsets: UIEdgeInsets, for state: DraggableState)

    func canDrag(from state: DraggableState) -> Bool

    func animate(progress: Double, from oldState: DraggableState, to newState: DraggableState, finalFrame: CGRect)
}
