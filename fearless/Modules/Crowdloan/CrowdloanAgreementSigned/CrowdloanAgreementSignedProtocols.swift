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

protocol CrowdloanAgreementSignedWireframeProtocol: WebPresentable {
    func presentContributionSetup(
        from view: CrowdloanAgreementSignedViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    )
}
