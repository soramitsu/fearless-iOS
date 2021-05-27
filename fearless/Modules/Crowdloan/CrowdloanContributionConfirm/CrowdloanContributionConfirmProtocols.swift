import SoraFoundation

protocol CrowdloanContributionConfirmViewProtocol: ControllerBackedProtocol, Localizable {}

protocol CrowdloanContributionConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanContributionConfirmInteractorInputProtocol: AnyObject {}

protocol CrowdloanContributionConfirmInteractorOutputProtocol: AnyObject {}

protocol CrowdloanContributionConfirmWireframeProtocol: AnyObject {}
