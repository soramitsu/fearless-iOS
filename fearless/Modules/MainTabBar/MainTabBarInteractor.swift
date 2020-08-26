import Foundation

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        presenter?.didReloadSelectedAccount()
    }
}
