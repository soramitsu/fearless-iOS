protocol CrowdloanAgreementConfirmViewProtocol: ControllerBackedProtocol {}

protocol CrowdloanAgreementConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanAgreementConfirmInteractorInputProtocol: AnyObject {
    func estimateFee()
}

protocol CrowdloanAgreementConfirmInteractorOutputProtocol: AnyObject {}

protocol CrowdloanAgreementConfirmWireframeProtocol: AnyObject {}
