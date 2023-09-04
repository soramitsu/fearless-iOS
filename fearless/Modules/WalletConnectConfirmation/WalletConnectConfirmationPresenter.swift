import Foundation
import SoraFoundation

protocol WalletConnectConfirmationViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletConnectConfirmationViewModel)
}

protocol WalletConnectConfirmationInteractorInput: AnyObject {
    func setup(with output: WalletConnectConfirmationInteractorOutput)
    func reject() async throws
    func approve() async throws -> String?
}

final class WalletConnectConfirmationPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectConfirmationViewInput?
    private let router: WalletConnectConfirmationRouterInput
    private let interactor: WalletConnectConfirmationInteractorInput

    private let inputData: WalletConnectConfirmationInputData
    private let viewModelFactory: WalletConnectConfirmationViewModelFactory

    // MARK: - Constructors

    init(
        inputData: WalletConnectConfirmationInputData,
        viewModelFactory: WalletConnectConfirmationViewModelFactory,
        interactor: WalletConnectConfirmationInteractorInput,
        router: WalletConnectConfirmationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.inputData = inputData
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel()
        view?.didReceive(viewModel: viewModel)
    }

    private func showAllDone(hash: String?) {
        router.showAllDone(
            chain: inputData.chain,
            hashString: hash,
            view: view
        ) { [weak self] in
            self?.router.comlete(from: self?.view)
        }
    }

    private func show(error: Error) {
        guard let view = view else {
            return
        }
        router.presentError(
            for: "",
            message: error.localizedDescription,
            view: view,
            locale: selectedLocale
        )
    }
}

// MARK: - WalletConnectConfirmationViewOutput

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationViewOutput {
    func viewDidDisappear() {
        Task {
            try? await interactor.reject()
        }
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func rawDataDidTapped() {
        router.showRawData(text: inputData.payload.stringRepresentation, from: view)
    }

    func confirmDidTapped() {
        view?.didStartLoading()
        Task {
            do {
                let hash = try await interactor.approve()
                await MainActor.run {
                    showAllDone(hash: hash)
                    view?.didStopLoading()
                }
            } catch {
                await MainActor.run {
                    view?.didStopLoading()
                    show(error: error)
                }
            }
        }
    }

    func didLoad(view: WalletConnectConfirmationViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - WalletConnectConfirmationInteractorOutput

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationInteractorOutput {}

// MARK: - Localizable

extension WalletConnectConfirmationPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationModuleInput {}
