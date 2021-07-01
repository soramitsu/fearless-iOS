import SoraFoundation

protocol ExperimentalListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(options: [String])
}

protocol ExperimentalListPresenterProtocol: AnyObject {
    func setup()

    func selectOption(at index: Int)
}

protocol ExperimentalListInteractorInputProtocol: AnyObject {}

protocol ExperimentalListInteractorOutputProtocol: AnyObject {}

protocol ExperimentalListWireframeProtocol: AnyObject {
    func showNotificationSettings(from view: ExperimentalListViewProtocol?)
    func showMobileSigning(from view: ExperimentalListViewProtocol?)
}
