import Foundation

final class CrowdloanListPresenter {
    weak var view: CrowdloanListViewProtocol?
    let wireframe: CrowdloanListWireframeProtocol
    let interactor: CrowdloanListInteractorInputProtocol

    init(
        interactor: CrowdloanListInteractorInputProtocol,
        wireframe: CrowdloanListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CrowdloanListPresenter: CrowdloanListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func refresh() {
        interactor.refresh()
    }
}

extension CrowdloanListPresenter: CrowdloanListInteractorOutputProtocol {}
