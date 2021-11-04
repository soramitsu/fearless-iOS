import SoraFoundation

protocol CrowdloanListViewProtocol: ControllerBackedProtocol {
    func didReceive(state: CrowdloanListState)
}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func setup()
    func refresh(shouldReset: Bool)
    func selectViewModel(_ viewModel: CrowdloanSectionItem<ActiveCrowdloanViewModel>)
    func becomeOnline()
    func putOffline()
}

protocol CrowdloanListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func becomeOnline()
    func putOffline()
}

protocol CrowdloanListInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
    func didReceiveContributions(result: Result<CrowdloanContributionDict, Error>)
    func didReceiveLeaseInfo(result: Result<ParachainLeaseInfoDict, Error>)
}

protocol CrowdloanListWireframeProtocol: AnyObject {
    func presentContributionSetup(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow?
    )

    func presentAgreement(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    )
}
