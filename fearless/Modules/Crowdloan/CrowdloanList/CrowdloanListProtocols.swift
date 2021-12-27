import SoraFoundation

protocol CrowdloanListModuleOutput: AnyObject {
    func didReceiveFailedMemos()
}

protocol CrowdloanListViewProtocol: ControllerBackedProtocol {
    func didReceive(state: CrowdloanListState)
    func didReceive(tabBarNotifications: Bool)
}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func setup()
    func refresh(shouldReset: Bool)
    func selectViewModel(_ viewModel: CrowdloanSectionItem<ActiveCrowdloanViewModel>)
    func selectCompleted(_ viewModel: CrowdloanSectionItem<CompletedCrowdloanViewModel>)
    func becomeOnline()
    func putOffline()
}

protocol CrowdloanListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func becomeOnline()
    func putOffline()
    func requestMemoHistory()
}

protocol CrowdloanListInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
    func didReceiveContributions(result: Result<CrowdloanContributionDict, Error>)
    func didReceiveLeaseInfo(result: Result<ParachainLeaseInfoDict, Error>)
    func didReceiveFailedMemos(result: Result<[ParaId: String], Error>)
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
