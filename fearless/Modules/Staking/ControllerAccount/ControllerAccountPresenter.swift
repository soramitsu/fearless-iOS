import Foundation
import SoraFoundation

final class ControllerAccountPresenter {
    let wireframe: ControllerAccountWireframeProtocol
    let interactor: ControllerAccountInteractorInputProtocol
    let viewModelFactory: ControllerAccountViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    weak var view: ControllerAccountViewProtocol?

    private var stashItem: StashItem?

    init(
        wireframe: ControllerAccountWireframeProtocol,
        interactor: ControllerAccountInteractorInputProtocol,
        viewModelFactory: ControllerAccountViewModelFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.applicationConfig = applicationConfig
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(stashItem: stashItem)
        view?.reload(with: viewModel)
    }
}

extension ControllerAccountPresenter: ControllerAccountPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleControllerAction() {}

    func handleStashAction() {}

    func selectLearnMore() {
        guard let view = view else { return }
        wireframe.showWeb(
            url: applicationConfig.learnControllerAccountURL,
            from: view,
            style: .automatic
        )
    }

    func proceed() {
        wireframe.showConfirmation(from: view)
    }
}

extension ControllerAccountPresenter: ControllerAccountInteractorOutputProtocol {
    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
            updateView()
        case let .failure(error):
            print(error)
        }
    }
}
