import Foundation

final class ManageAssetsPresenter {
    weak var view: ManageAssetsViewProtocol?
    let wireframe: ManageAssetsWireframeProtocol
    let interactor: ManageAssetsInteractorInputProtocol

    init(
        interactor: ManageAssetsInteractorInputProtocol,
        wireframe: ManageAssetsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ManageAssetsPresenter: ManageAssetsPresenterProtocol {
    func setup() {}
}

extension ManageAssetsPresenter: ManageAssetsInteractorOutputProtocol {}