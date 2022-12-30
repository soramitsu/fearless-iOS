import SoraFoundation

final class SelectedValidatorListPresenter {
    weak var view: SelectedValidatorListViewProtocol?
    private let wireframe: SelectedValidatorListWireframeProtocol
    private let viewModelFactory: SelectedValidatorListViewModelFactoryProtocol
    private let viewModelState: SelectedValidatorListViewModelState
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel

    init(
        wireframe: SelectedValidatorListWireframeProtocol,
        viewModelFactory: SelectedValidatorListViewModelFactoryProtocol,
        viewModelState: SelectedValidatorListViewModelState,
        localizationManager: LocalizationManagerProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func createViewModel() -> SelectedValidatorListViewModel? {
        viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            locale: selectedLocale
        )
    }

    private func provideViewModel() {
        guard let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            locale: selectedLocale
        ) else {
            return
        }

        view?.didReload(viewModel)
    }
}

// MARK: - SelectedValidatorListPresenterProtocol

extension SelectedValidatorListPresenter: SelectedValidatorListPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)
        provideViewModel()
    }

    func didSelectValidator(at index: Int) {
        guard let flow = viewModelState.validatorInfoFlow(validatorIndex: index) else {
            return
        }

        wireframe.present(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func removeItem(at index: Int) {
        viewModelState.removeItem(at: index)
    }

    func proceed() {
        guard let flow = viewModelState.selectValidatorsConfirmFlow() else {
            return
        }

        wireframe.proceed(
            from: view,
            flow: flow,
            wallet: wallet,
            chainAsset: chainAsset
        )
    }

    func dismiss() {
        wireframe.dismiss(view)
    }
}

// MARK: - Localizable

extension SelectedValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}

extension SelectedValidatorListPresenter: SelectedValidatorListModelStateListener {
    func modelStateDidChanged(viewModelState _: SelectedValidatorListViewModelState) {
        provideViewModel()
    }

    func validatorRemovedAtIndex(_ index: Int, viewModelState _: SelectedValidatorListViewModelState) {
        guard let viewModel = createViewModel() else {
            return
        }

        view?.didChangeViewModel(viewModel, byRemovingItemAt: index)
    }
}
