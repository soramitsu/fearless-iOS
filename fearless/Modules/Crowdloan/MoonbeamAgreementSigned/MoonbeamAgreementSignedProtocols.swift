protocol MoonbeamAgreementSignedViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MoonbeamAgreementSignedViewModel)
}

protocol MoonbeamAgreementSignedPresenterProtocol: AnyObject {
    func setup()

    func actionContinue()
    func seeHash()
}

protocol MoonbeamAgreementSignedInteractorInputProtocol: AnyObject {}

protocol MoonbeamAgreementSignedInteractorOutputProtocol: AnyObject {}

protocol MoonbeamAgreementSignedWireframeProtocol: AnyObject {
    func presentContributionSetup(
        from view: MoonbeamAgreementSignedViewProtocol?,
        paraId: ParaId
    )
}
