import Foundation
import SoraFoundation

final class UsernameSetupPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var interactor: UsernameSetupInteractorInputProtocol!

    private var metadata: UsernameSetupMetadata?
    private var selectedNetwork: Chain?

    private var viewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        return InputViewModel(inputHandler: inputHandling)
    }()

    private func provideNetworkViewModel() {
        guard let network = selectedNetwork else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let contentViewModel = IconWithTitleViewModel(
            icon: network.icon,
            title: network.titleForLocale(locale)
        )

        let selectable = (metadata?.availableNetworks.count ?? 0) > 1
        let viewModel = SelectableViewModel(
            underlyingViewModel: contentViewModel,
            selectable: selectable
        )

        view?.setSelectedNetwork(model: viewModel)
    }
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        view?.setInput(viewModel: viewModel)
        interactor.setup()
    }

    func proceed() {
        guard let selectedNetwork = selectedNetwork else {
            return
        }

        let username = viewModel.inputHandler.value

        let rLanguages = localizationManager?.selectedLocale.rLanguages
        let actionTitle = R.string.localizable.commonOk(preferredLanguages: rLanguages)
        let action = AlertPresentableAction(title: actionTitle) { [weak self] in
            let model = UsernameSetupModel(username: username, selectedNetwork: selectedNetwork)
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

    func selectNetworkType() {
        if let metadata = metadata {
            let network = selectedNetwork ?? metadata.defaultNetwork
            wireframe.presentNetworkTypeSelection(
                from: view,
                availableTypes: metadata.availableNetworks,
                selectedType: network,
                delegate: self,
                context: nil
            )
        }
    }
}

extension UsernameSetupPresenter: UsernameSetupInteractorOutputProtocol {
    func didReceive(metadata: UsernameSetupMetadata) {
        self.metadata = metadata

        selectedNetwork = metadata.defaultNetwork

        provideNetworkViewModel()
    }
}

extension UsernameSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        selectedNetwork = metadata?.availableNetworks[index]

        provideNetworkViewModel()

        view?.didCompleteNetworkSelection()
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        view?.didCompleteNetworkSelection()
    }
}

extension UsernameSetupPresenter: Localizable {
    func applyLocalization() {}
}
