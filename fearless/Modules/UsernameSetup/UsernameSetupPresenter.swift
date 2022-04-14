import Foundation
import SoraFoundation

final class UsernameSetupPresenter {
    private weak var view: UsernameSetupViewProtocol?
    private var wireframe: UsernameSetupWireframeProtocol
    private let flow: AccountCreateFlow

    private var viewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        return InputViewModel(inputHandler: inputHandling)
    }()

    init(
        wireframe: UsernameSetupWireframeProtocol,
        flow: AccountCreateFlow,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.flow = flow
        self.localizationManager = localizationManager
    }
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func didLoad(view: UsernameSetupViewProtocol) {
        view.bindUsername(viewModel: viewModel)
        if case let .chain(model) = flow {
            let uniqueChainModel = UniqueChainViewModel(
                text: model.chain.name,
                icon: model.chain.icon.map { RemoteImageViewModel(url: $0) }
            )
            view.bindUniqueChain(viewModel: uniqueChainModel)
        }
        self.view = view
    }

    func proceed() {
        let username = viewModel.inputHandler.value

        let rLanguages = localizationManager?.selectedLocale.rLanguages
        let actionTitle = R.string.localizable.commonOk(preferredLanguages: rLanguages)
        let action = AlertPresentableAction(title: actionTitle) { [weak self] in
            guard let self = self else { return }
            let model = UsernameSetupModel(username: username)
            self.wireframe.proceed(from: self.view, flow: self.flow, model: model)
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
