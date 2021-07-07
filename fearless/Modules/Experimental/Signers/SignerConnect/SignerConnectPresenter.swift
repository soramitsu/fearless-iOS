import Foundation

final class SignerConnectPresenter {
    weak var view: SignerConnectViewProtocol?
    let wireframe: SignerConnectWireframeProtocol
    let interactor: SignerConnectInteractorInputProtocol
    let viewModelFactory: SignerConnectViewModelFactoryProtocol
    let chain: Chain

    private var metadata: BeaconConnectionInfo?
    private var account: AccountItem?

    init(
        interactor: SignerConnectInteractorInputProtocol,
        wireframe: SignerConnectWireframeProtocol,
        viewModelFactory: SignerConnectViewModelFactoryProtocol,
        chain: Chain
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
    }

    private func provideViewModel() {
        guard let metadata = metadata, let account = account else {
            return
        }

        do {
            let viewModel = try viewModelFactory.createViewModel(from: metadata, account: account)
            view?.didReceive(viewModel: viewModel)
        } catch {
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: view?.selectedLocale)
        }
    }
}

extension SignerConnectPresenter: SignerConnectPresenterProtocol {
    func setup() {
        view?.didReceive(status: .connecting)
        interactor.setup()
        interactor.connect()
    }

    func presentAccountOptions() {
        guard let view = view, let account = account else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: account.address,
            chain: chain,
            locale: view.selectedLocale
        )
    }

    func presentConnectionDetails() {
        guard let metadata = metadata else {
            return
        }

        let languages = view?.selectedLocale.rLanguages
        let title = R.string.localizable.signerConnectAddressFormat(
            metadata.name,
            preferredLanguages: languages
        )

        wireframe.present(
            message: metadata.relayServer,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            from: view
        )
    }
}

extension SignerConnectPresenter: SignerConnectInteractorOutputProtocol {
    func didReceive(request: SignerOperationRequestProtocol) {
        wireframe.showConfirmation(from: view, request: request)
    }

    func didReceive(account: Result<AccountItem?, Error>) {
        switch account {
        case let .success(account):
            self.account = account
            provideViewModel()
        case let .failure(error):
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: view?.selectedLocale)
        }
    }

    func didReceiveApp(metadata: BeaconConnectionInfo) {
        self.metadata = metadata
        provideViewModel()
    }

    func didReceiveConnection(result: Result<Void, Error>) {
        switch result {
        case .success:
            view?.didReceive(status: .active)
        case .failure:
            view?.didReceive(status: .failed)
        }
    }

    func didReceiveProtocol(error: Error) {
        wireframe.presentErrorOrUndefined(error: error, from: view, locale: view?.selectedLocale)
    }
}
