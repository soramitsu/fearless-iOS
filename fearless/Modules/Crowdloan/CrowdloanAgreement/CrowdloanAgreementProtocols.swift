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
}

protocol CrowdloanAgreementWireframeProtocol: AnyObject {
    func showAgreementConfirm(
        from view: CrowdloanAgreementViewProtocol?,
        paraId: ParaId
    )
}
