import Foundation
import SoraFoundation

final class PolkaswapSwapConfirmationPresenter {
    // MARK: Private properties

    private weak var view: PolkaswapSwapConfirmationViewInput?
    private let router: PolkaswapSwapConfirmationRouterInput
    private let interactor: PolkaswapSwapConfirmationInteractorInput

    private var params: PolkaswapPreviewParams
    private let viewModelFactory: PolkaswapSwapConfirmationViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        params: PolkaswapPreviewParams,
        viewModelFactory: PolkaswapSwapConfirmationViewModelFactoryProtocol,
        interactor: PolkaswapSwapConfirmationInteractorInput,
        router: PolkaswapSwapConfirmationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.params = params
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory
            .createViewModel(with: params, locale: selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - PolkaswapSwapConfirmationViewOutput

extension PolkaswapSwapConfirmationPresenter: PolkaswapSwapConfirmationViewOutput {
    func didLoad(view: PolkaswapSwapConfirmationViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapConfirmButton() {
        view?.didStartLoading()
        interactor.submit()
    }
}

// MARK: - PolkaswapSwapConfirmationInteractorOutput

extension PolkaswapSwapConfirmationPresenter: PolkaswapSwapConfirmationInteractorOutput {
    func didReceive(extrinsicResult: SubmitExtrinsicResult) {
        view?.didStopLoading()

        switch extrinsicResult {
        case let .success(hash):
            router.complete(on: view, title: hash)
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

extension PolkaswapSwapConfirmationPresenter: Localizable {
    func applyLocalization() {}
}

extension PolkaswapSwapConfirmationPresenter: PolkaswapSwapConfirmationModuleInput {
    func updateModule(with params: PolkaswapPreviewParams) {
        self.params = params
        interactor.update(params: params)
        provideViewModel()
    }
}
