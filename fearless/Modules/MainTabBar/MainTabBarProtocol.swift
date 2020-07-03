import UIKit

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: class {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: class {}

protocol MainTabBarInteractorOutputProtocol: class {}

protocol MainTabBarWireframeProtocol: AlertPresentable {}

protocol MainTabBarViewFactoryProtocol: class {
    static func createView() -> MainTabBarViewProtocol?
}
