import Foundation

final class CrowdloanAgreementConfirmPresenter {
    weak var view: CrowdloanAgreementConfirmViewProtocol?
    let wireframe: CrowdloanAgreementConfirmWireframeProtocol
    let interactor: CrowdloanAgreementConfirmInteractorInputProtocol

    init(
        interactor: CrowdloanAgreementConfirmInteractorInputProtocol,
        wireframe: CrowdloanAgreementConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CrowdloanAgreementConfirmPresenter: CrowdloanAgreementConfirmPresenterProtocol {
    func setup() {}
}

extension CrowdloanAgreementConfirmPresenter: CrowdloanAgreementConfirmInteractorOutputProtocol {}
