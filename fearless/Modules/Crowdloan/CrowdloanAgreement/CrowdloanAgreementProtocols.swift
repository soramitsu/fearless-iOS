import Foundation
protocol CrowdloanAgreementViewProtocol: ControllerBackedProtocol {
    func didReceive(state: CrowdloanAgreementState)
}

protocol CrowdloanAgreementPresenterProtocol: AnyObject {
    func setup()
    func confirmAgreement()
    func setTermsAgreed(value: Bool)
}

protocol CrowdloanAgreementInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CrowdloanAgreementInteractorOutputProtocol: AnyObject {
    func didReceiveAgreementText(result: Result<String, Error>)
    func didReceiveVerified(result: Result<Bool, Error>)
}

protocol CrowdloanAgreementWireframeProtocol: AlertPresentable {
    func showMoonbeamAgreementConfirm(
        from view: CrowdloanAgreementViewProtocol?,
        paraId: ParaId,
        moonbeamFlowData: MoonbeamFlowData
    )

    func presentContributionSetup(
        from view: CrowdloanAgreementViewProtocol?,
        paraId: ParaId
    )

    func presentUnavailableWarning(
        message: String?,
        view: ControllerBackedProtocol,
        locale: Locale?
    )
}
