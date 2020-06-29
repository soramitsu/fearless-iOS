import Foundation

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {}
