import Foundation

final class ManageAssetsPresenter {
    weak var view: ManageAssetsViewProtocol?
    private let wireframe: ManageAssetsWireframeProtocol
    private let interactor: ManageAssetsInteractorInputProtocol
    private let viewModelFactory: ManageAssetsViewModelFactoryProtocol

    init(
        interactor: ManageAssetsInteractorInputProtocol,
        wireframe: ManageAssetsWireframeProtocol,
        viewModelFactory: ManageAssetsViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }
}

extension ManageAssetsPresenter: ManageAssetsPresenterProtocol {
    func setup() {}
}

extension ManageAssetsPresenter: ManageAssetsInteractorOutputProtocol {
    func didReceiveChains(result _: Result<[ChainModel], Error>) {}

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainModel.Id) {}
}
