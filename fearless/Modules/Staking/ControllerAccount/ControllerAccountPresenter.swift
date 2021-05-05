import Foundation
import SoraFoundation

final class ControllerAccountPresenter {
    let wireframe: ControllerAccountWireframeProtocol
    let interactor: ControllerAccountInteractorInputProtocol
    let applicationConfig: ApplicationConfigProtocol
    weak var view: ControllerAccountViewProtocol?

    init(
        wireframe: ControllerAccountWireframeProtocol,
        interactor: ControllerAccountInteractorInputProtocol,
        applicationConfig: ApplicationConfigProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.applicationConfig = applicationConfig
    }
}

extension ControllerAccountPresenter: ControllerAccountPresenterProtocol {
    func setup() {
        let stash = AccountInfoViewModel(
            title: "Stash account",
            address: "🐟 ANDREY",
            name: "name",
            icon: nil
        )
        let controller = AccountInfoViewModel(
            title: "Controller account",
            address: "🐟 ANDREY",
            name: "name",
            icon: nil
        )
        let rows: [ControllerAccountRow] = [
            .stash(stash),
            .controller(controller),
            .learnMore
        ]
        let viewModel = LocalizableResource<ControllerAccountViewModel> { _ in
            .init(rows: rows)
        }
        view?.reload(with: viewModel)
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
}

extension ControllerAccountPresenter: ControllerAccountInteractorOutputProtocol {}
