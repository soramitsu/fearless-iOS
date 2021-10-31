protocol CrowdloanAgreementSignedViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: CrowdloanAgreementSignedViewModel)
}

protocol CrowdloanAgreementSignedPresenterProtocol: AnyObject {
    func setup()

    func actionContinue()
    func seeHash()
}

protocol CrowdloanAgreementSignedInteractorInputProtocol: AnyObject {}

protocol CrowdloanAgreementSignedInteractorOutputProtocol: AnyObject {}

protocol CrowdloanAgreementSignedWireframeProtocol: AnyObject {
    func presentContributionSetup(
        from view: CrowdloanAgreementSignedViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    )
}
