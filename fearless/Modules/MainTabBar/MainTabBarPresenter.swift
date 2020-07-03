import Foundation

final class MainTabBarPresenter {
	weak var view: MainTabBarViewProtocol?
	var interactor: MainTabBarInteractorInputProtocol!
	var wireframe: MainTabBarWireframeProtocol!
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {}

    func viewDidAppear() {}
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {}
