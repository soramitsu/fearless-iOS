import SoraFoundation

protocol CrowdloanListViewProtocol: ControllerBackedProtocol {
    func didReceive(state: CrowdloanListState)
}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func setup()
    func refresh(shouldReset: Bool)
}

protocol CrowdloanListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol CrowdloanListInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
}

protocol CrowdloanListWireframeProtocol: AnyObject {}
