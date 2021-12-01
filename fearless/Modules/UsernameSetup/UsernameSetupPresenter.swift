import Foundation
import SoraFoundation

final class UsernameSetupPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!

    private var viewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        return InputViewModel(inputHandler: inputHandling)
    }()
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        view?.setInput(viewModel: viewModel)
    }

    func proceed() {
        let username = viewModel.inputHandler.value

        let rLanguages = localizationManager?.selectedLocale.rLanguages
        let actionTitle = R.string.localizable.commonOk(preferredLanguages: rLanguages)
        let action = AlertPresentableAction(title: actionTitle) { [weak self] in
            let model = UsernameSetupModel(username: username)
            self?.wireframe.proceed(from: self?.view, model: model)
        }

        let title = R.string.localizable.commonNoScreenshotTitle(preferredLanguages: rLanguages)
        let message = R.string.localizable.commonNoScreenshotMessage(preferredLanguages: rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [action],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }
}

extension UsernameSetupPresenter: Localizable {
    func applyLocalization() {}
}
