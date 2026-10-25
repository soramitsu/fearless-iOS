import Foundation
import SoraFoundation
import SSFModels

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let logger: LoggerProtocol?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel

    let viewModelState: CustomValidatorListViewModelState
    let viewModelFactory: CustomValidatorListViewModelFactoryProtocol

    private var searchText: String?

    init(
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactoryProtocol,
        viewModelState: CustomValidatorListViewModelState,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.logger = logger
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func provideFilterButtonViewModel() {
        view?.setFilterAppliedState(to: viewModelState.filterApplied)
    }

    private func provideViewModels(viewModelState: CustomValidatorListViewModelState) {
        provideFilterButtonViewModel()

        if let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency),
            locale: selectedLocale,
            searchText: searchText
        ) {
            self.viewModelState.updateViewModel(viewModel)
            view?.reload(viewModel)
        }
    }

    private func performDeselect() {
        viewModelState.performDeselect()
    }

    private func handleValidatorBlockedError() {
        wireframe.present(
            message: R.string.localizable
                .stakingCustomBlockedWarning(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable
                .commonWarning(preferredLanguages: selectedLocale.rLanguages),
            closeAction: R.string.localizable
                .commonClose(preferredLanguages: selectedLocale.rLanguages),
            from: view
        )
    }
}

// MARK: - CustomValidatorListPresenterProtocol

extension CustomValidatorListPresenter: CustomValidatorListPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        provideViewModels(viewModelState: viewModelState)
    }

    // MARK: - Header actions

    func fillWithRecommended() {
        viewModelState.fillWithRecommended()
    }

    func clearFilter() {
        viewModelState.clearFilter()

        provideViewModels(viewModelState: viewModelState)
    }

    func deselectAll() {
        guard let view = view else { return }

        wireframe.presentDeselectValidatorsWarning(
            from: view,
            action: performDeselect,
            locale: selectedLocale
        )
    }

    func changeIdentityFilterValue() {
        viewModelState.changeIdentityFilterValue()
    }

    func changeMinBondFilterValue() {
        viewModelState.changeMinBondFilterValue()
    }

    // MARK: - Cell actions

    func changeValidatorSelection(address: String) {
        viewModelState.changeValidatorSelection(address: address)
    }

    // MARK: - Presenting actions

    func didSelectValidator(address: String) {
        guard let flow = viewModelState.validatorInfoFlow(address: address) else {
            return
        }

        wireframe.present(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            from: view
        )
    }

    func presentFilter() {
        guard let flow = viewModelState.validatorListFilterFlow() else {
            return
        }

        wireframe.presentFilters(
            from: view,
            flow: flow,
            delegate: self,
            asset: chainAsset.asset
        )
    }

    func presentSearch() {
        guard let flow = viewModelState.validatorSearchFlow() else {
            return
        }

        wireframe.presentSearch(
            from: view,
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func proceed() {
        viewModelState.proceed()
    }

    func searchTextDidChange(_ text: String?) {
        searchText = text
        provideViewModels(viewModelState: viewModelState)
    }
}

// MARK: - SelectedValidatorListDelegate

extension CustomValidatorListPresenter: SelectedValidatorListDelegate {
    func didRemove(_ validator: SelectedValidatorInfo) {
        viewModelState.remove(validator: validator)
    }

    func didRemove(validatorAddress: AccountAddress) {
        viewModelState.remove(validatorAddress: validatorAddress)
    }
}

// MARK: - ValidatorListFilterDelegate

extension CustomValidatorListPresenter: ValidatorListFilterDelegate {
    func didUpdate(with flow: ValidatorListFilterFlow) {
        viewModelState.updateFilter(with: flow)
        provideViewModels(viewModelState: viewModelState)
    }
}

// MARK: - Localizable

extension CustomValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels(viewModelState: viewModelState)
        }
    }
}

extension CustomValidatorListPresenter: CustomValidatorListModelStateListener {
    func didReceiveError(error: CustomValidatorListFlowError) {
        switch error {
        case .validatorBlocked:
            handleValidatorBlockedError()
        }
    }

    func modelStateDidChanged(viewModelState: CustomValidatorListViewModelState) {
        provideViewModels(viewModelState: viewModelState)
    }

    func showSelectedList() {
        guard let flow = viewModelState.selectedValidatorListFlow() else {
            return
        }

        wireframe.proceed(
            from: view,
            flow: flow,
            delegate: self,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func showConfirmation() {
        guard let flow = viewModelState.selectValidatorsConfirmFlow() else {
            return
        }

        wireframe.confirm(
            from: view,
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }
}
