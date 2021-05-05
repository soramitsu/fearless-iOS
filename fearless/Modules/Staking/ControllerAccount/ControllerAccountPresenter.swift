import Foundation
import SoraFoundation

final class ControllerAccountPresenter {
    weak var view: ControllerAccountViewProtocol?
    var wireframe: ControllerAccountWireframeProtocol!
    var interactor: ControllerAccountInteractorInputProtocol!
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
}

extension ControllerAccountPresenter: ControllerAccountInteractorOutputProtocol {}
