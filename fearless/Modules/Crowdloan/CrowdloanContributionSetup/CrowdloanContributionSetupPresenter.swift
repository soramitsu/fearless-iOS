import Foundation

final class CrowdloanContributionSetupPresenter {
    weak var view: CrowdloanContributionSetupViewProtocol?
    let wireframe: CrowdloanContributionSetupWireframeProtocol
    let interactor: CrowdloanContributionSetupInteractorInputProtocol

    init(
        interactor: CrowdloanContributionSetupInteractorInputProtocol,
        wireframe: CrowdloanContributionSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupPresenterProtocol {
    func setup() {}
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupInteractorOutputProtocol {}
