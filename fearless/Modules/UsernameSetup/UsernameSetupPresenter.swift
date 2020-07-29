import Foundation
import SoraFoundation

final class UsernameSetupPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!

    private var viewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(predicate: NSPredicate.notEmpty)
        return InputViewModel(inputHandler: inputHandling)
    }()
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        view?.set(viewModel: viewModel)
    }

    func proceed() {
        wireframe.proceed(username: viewModel.inputHandler.value)
    }
}
