import SoraFoundation

import SSFModels

final class ValidatorListFilterPresenter {
    weak var view: ValidatorListFilterViewProtocol?
    weak var delegate: ValidatorListFilterDelegate?

    let wireframe: ValidatorListFilterWireframeProtocol
    let viewModelFactory: ValidatorListFilterViewModelFactoryProtocol
    let viewModelState: ValidatorListFilterViewModelState
    let asset: AssetModel

    init(
        wireframe: ValidatorListFilterWireframeProtocol,
        viewModelFactory: ValidatorListFilterViewModelFactoryProtocol,
        viewModelState: ValidatorListFilterViewModelState,
        asset: AssetModel,
        localizationManager: LocalizationManager
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.asset = asset
        self.localizationManager = localizationManager
    }

    private func provideViewModels() {
        guard let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            token: asset.symbol.uppercased(),
            locale: selectedLocale
        ) else {
            return
        }

        view?.didUpdateViewModel(viewModel)
    }
}

extension ValidatorListFilterPresenter: ValidatorListFilterPresenterProtocol {
    func toggleFilterItem(at index: Int) {
        viewModelState.toggleFilterItem(at: index)
    }

    func selectFilterItem(at index: Int) {
        viewModelState.selectFilterItem(at: index)
    }

    func resetFilter() {
        viewModelState.resetFilter()
    }

    func setup() {
        provideViewModels()

        viewModelState.setStateListener(self)
    }

    func applyFilter() {
        guard let flow = viewModelState.validatorListFilterFlow() else {
            return
        }

        delegate?.didUpdate(with: flow)
        wireframe.close(view)
    }
}

extension ValidatorListFilterPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}

extension ValidatorListFilterPresenter: ValidatorListFilterModelStateListener {
    func modelStateDidChanged(viewModelState _: ValidatorListFilterViewModelState) {
        provideViewModels()
    }
}
