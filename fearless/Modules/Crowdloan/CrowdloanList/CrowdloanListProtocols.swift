import SoraFoundation

protocol CrowdloanListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(state: CrowdloanListState)
    func didUpdateProgress(for viewModel: CrowdloansViewModel)
}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol CrowdloanListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol CrowdloanListInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>)
}

protocol CrowdloanListWireframeProtocol: AnyObject {}
