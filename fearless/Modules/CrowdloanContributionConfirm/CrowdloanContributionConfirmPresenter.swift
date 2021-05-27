import Foundation

final class CrowdloanContributionConfirmPresenter {
    weak var view: CrowdloanContributionConfirmViewProtocol?
    let wireframe: CrowdloanContributionConfirmWireframeProtocol
    let interactor: CrowdloanContributionConfirmInteractorInputProtocol

    init(
        interactor: CrowdloanContributionConfirmInteractorInputProtocol,
        wireframe: CrowdloanContributionConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CrowdloanContributionConfirmPresenter: CrowdloanContributionConfirmPresenterProtocol {
    func setup() {}
}

extension CrowdloanContributionConfirmPresenter: CrowdloanContributionConfirmInteractorOutputProtocol {}
