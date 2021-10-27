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
    func agreeRemark() throws
}

protocol CrowdloanAgreementInteractorOutputProtocol: AnyObject {
    func didReceiveAgreementText(result: Result<String, Error>)
    func didReceiveVerified(result: Result<Bool, Error>)
    func didReceiveRemark(result: Result<MoonbeamAgreeRemarkData, Error>)
}

protocol CrowdloanAgreementWireframeProtocol: AlertPresentable, ErrorPresentable {
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
