import Foundation
import SoraFoundation

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let logger: LoggerProtocol?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel

    let viewModelState: CustomValidatorListViewModelState
    let viewModelFactory: CustomValidatorListViewModelFactoryProtocol

    private var priceData: PriceData?

    init(
        interactor: CustomValidatorListInteractorInputProtocol,
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactoryProtocol,
        viewModelState: CustomValidatorListViewModelState,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
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
        let emptyFilter = CustomValidatorListFilter.defaultFilter()
        let appliedState = viewModelState.filter != emptyFilter

        view?.setFilterAppliedState(to: appliedState)
    }

    private func provideViewModels(viewModelState: CustomValidatorListViewModelState) {
        provideFilterButtonViewModel()

        if let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            priceData: priceData,
            locale: selectedLocale
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
        provideViewModels(viewModelState: viewModelState)
        interactor.setup()

        viewModelState.setStateListener(self)
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

    // MARK: - Cell actions

    func changeValidatorSelection(at index: Int) {
        viewModelState.changeValidatorSelection(at: index)
    }

    // MARK: - Presenting actions

    func didSelectValidator(at index: Int) {
        guard let flow = viewModelState.validatorInfoFlow(validatorIndex: index) else {
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
            delegate: self,
            chainAsset: chainAsset
        )
    }

    func proceed() {
        // TODO: transition with new parameters

//        wireframe.proceed(
//            from: view,
//            validatorList: selectedValidatorList.items,
//            maxTargets: maxTargets,
//            delegate: self,
//            chain: chainAsset.chain,
//            asset: chainAsset.asset,
//            selectedAccount: wallet
//        )
    }
}

// MARK: - CustomValidatorListInteractorOutputProtocol

extension CustomValidatorListPresenter: CustomValidatorListInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideViewModels(viewModelState: viewModelState)
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }
}

// MARK: - SelectedValidatorListDelegate

extension CustomValidatorListPresenter: SelectedValidatorListDelegate {
    func didRemove(_ validator: SelectedValidatorInfo) {
        viewModelState.remove(validator: validator)
    }
}

// MARK: - ValidatorListFilterDelegate

extension CustomValidatorListPresenter: ValidatorListFilterDelegate {
    func didUpdate(with flow: ValidatorListFilterFlow) {
        viewModelState.updateFilter(with: flow)
        provideViewModels(viewModelState: viewModelState)
    }
}

// MARK: - ValidatorSearchDelegate

extension CustomValidatorListPresenter: ValidatorSearchDelegate {
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo]) {
        viewModelState.validatorSearchDidUpdate(selectedValidatorList: selectedValidatorList)
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

    func viewModelChanged(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]?) {
        view?.reload(viewModel, at: indexes)
    }
}
