import Foundation
import SoraFoundation

protocol CrossChainConfirmationViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: CrossChainConfirmationViewModel)
}

protocol CrossChainConfirmationInteractorInput: AnyObject {
    func setup(with output: CrossChainConfirmationInteractorOutput)
    func submit()
}

final class CrossChainConfirmationPresenter {
    // MARK: Private properties

    private weak var view: CrossChainConfirmationViewInput?
    private let router: CrossChainConfirmationRouterInput
    private let interactor: CrossChainConfirmationInteractorInput

    private let teleportData: CrossChainConfirmationData
    private let viewModelFactory: CrossChainConfirmationViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        teleportData: CrossChainConfirmationData,
        viewModelFactory: CrossChainConfirmationViewModelFactoryProtocol,
        interactor: CrossChainConfirmationInteractorInput,
        router: CrossChainConfirmationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.teleportData = teleportData
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(with: teleportData)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - CrossChainConfirmationViewOutput

extension CrossChainConfirmationPresenter: CrossChainConfirmationViewOutput {
    func didLoad(view: CrossChainConfirmationViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func confirmButtonTapped() {
        view?.didStartLoading()
        interactor.submit()
    }
}

// MARK: - CrossChainConfirmationInteractorOutput

extension CrossChainConfirmationPresenter: CrossChainConfirmationInteractorOutput {
    func didTransfer(result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(hash):

            router.complete(on: view, title: hash, chainAsset: teleportData.originChainAsset)
        case let .failure(error):
            guard let view = view else {
                return
            }

            if !router.present(error: error, from: view, locale: selectedLocale) {
                router.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }
}

// MARK: - Localizable

extension CrossChainConfirmationPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainConfirmationPresenter: CrossChainConfirmationModuleInput {}
