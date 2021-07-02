import Foundation

final class ExperimentalListPresenter {
    weak var view: ExperimentalListViewProtocol?
    let wireframe: ExperimentalListWireframeProtocol
    let interactor: ExperimentalListInteractorInputProtocol

    init(
        interactor: ExperimentalListInteractorInputProtocol,
        wireframe: ExperimentalListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ExperimentalListPresenter: ExperimentalListPresenterProtocol {
    func setup() {
        guard let view = view else {
            return
        }

        let options = ExperimentalOption.allCases.map { $0.title(for: view.selectedLocale) }
        view.didReceive(options: options)
    }

    func selectOption(at index: Int) {
        guard let option = ExperimentalOption(rawValue: index) else {
            return
        }

        switch option {
        case .notifications:
            wireframe.showNotificationSettings(from: view)
        case .signer:
            wireframe.showBeaconConnection(from: view, delegate: self)
        }
    }
}

extension ExperimentalListPresenter: ExperimentalListInteractorOutputProtocol {}

extension ExperimentalListPresenter: BeaconQRDelegate {
    func didReceiveBeacon(connectionInfo: BeaconConnectionInfo) {
        wireframe.showBeaconSession(from: view, connectionInfo: connectionInfo)
    }
}
