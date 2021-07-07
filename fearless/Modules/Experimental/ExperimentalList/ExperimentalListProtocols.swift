import SoraFoundation

protocol ExperimentalListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(options: [ExperimentalOption])
}

protocol ExperimentalListPresenterProtocol: AnyObject {
    func setup()

    func selectOption(at index: Int)
}

protocol ExperimentalListInteractorInputProtocol: AnyObject {}

protocol ExperimentalListInteractorOutputProtocol: AnyObject {}

protocol ExperimentalListWireframeProtocol: AnyObject {
    func showNotificationSettings(from view: ExperimentalListViewProtocol?)
    func showBeaconConnection(from view: ExperimentalListViewProtocol?, delegate: BeaconQRDelegate)
    func showBeaconSession(from view: ExperimentalListViewProtocol?, connectionInfo: BeaconConnectionInfo)
}
