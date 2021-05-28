import Foundation

final class KaruraCrowdloanPresenter {
    weak var view: KaruraCrowdloanViewProtocol?
    let wireframe: KaruraCrowdloanWireframeProtocol
    let interactor: KaruraCrowdloanInteractorInputProtocol

    init(
        interactor: KaruraCrowdloanInteractorInputProtocol,
        wireframe: KaruraCrowdloanWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension KaruraCrowdloanPresenter: KaruraCrowdloanPresenterProtocol {
    func setup() {}
}

extension KaruraCrowdloanPresenter: KaruraCrowdloanInteractorOutputProtocol {}
