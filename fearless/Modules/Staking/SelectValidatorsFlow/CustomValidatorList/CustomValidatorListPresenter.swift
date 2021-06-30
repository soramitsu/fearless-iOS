import Foundation
import SoraFoundation

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let viewModelFactory: CustomValidatorListViewModelFactory
    let maxTargets: Int
    let logger: LoggerProtocol?

    private let recommendedValidatorList: [ElectedValidatorInfo]

    private var electedValidatorList: [ElectedValidatorInfo]
    private var filteredValidatorList: [ElectedValidatorInfo] = []
    private var selectedValidatorList: [ElectedValidatorInfo] = []
    private var viewModel: CustomValidatorListViewModel?
    private var filter = CustomValidatorListFilter.recommendedFilter()
    private var priceData: PriceData?

    init(
        interactor: CustomValidatorListInteractorInputProtocol,
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        electedValidators: [ElectedValidatorInfo],
        recommendedValidators: [ElectedValidatorInfo],
        maxTargets: Int,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        electedValidatorList = electedValidators
        recommendedValidatorList = recommendedValidators
        self.maxTargets = maxTargets
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func composeFilteredValidatorList() -> [ElectedValidatorInfo] {
        let composer = CustomValidatorListComposer(filter: filter)
        return composer.compose(from: electedValidatorList)
    }

    private func updateFilteredValidatorsList() {
        filteredValidatorList = composeFilteredValidatorList()
    }

    private func provideValidatorListViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            from: filteredValidatorList,
            selectedValidators: selectedValidatorList,
            totalValidatorsCount: electedValidatorList.count,
            filter: filter,
            priceData: priceData,
            locale: selectedLocale
        )

        self.viewModel = viewModel
        view?.reload(viewModel)
    }

    private func provideFilterButtonViewModel() {
        let emptyFilter = CustomValidatorListFilter.defaultFilter()
        let appliedState = filter != emptyFilter

        view?.setFilterAppliedState(to: appliedState)
    }

    private func provideViewModels() {
        updateFilteredValidatorsList()

        provideValidatorListViewModel()
        provideFilterButtonViewModel()
    }

    private func performDeselect() {
        guard var viewModel = viewModel else { return }

        let changedModels: [CustomValidatorCellViewModel] = viewModel.cellViewModels.map {
            var newItem = $0
            newItem.isSelected = false
            return newItem
        }

        let indices = viewModel.cellViewModels
            .enumerated()
            .filter {
                $1.isSelected
            }.map { index, _ in
                index
            }

        selectedValidatorList = []

        viewModel.cellViewModels = changedModels
        viewModel.selectedValidatorsCount = 0
        self.viewModel = viewModel

        view?.reload(viewModel, at: indices)
    }
}

// MARK: - CustomValidatorListPresenterProtocol

extension CustomValidatorListPresenter: CustomValidatorListPresenterProtocol {
    func setup() {
        provideViewModels()
        interactor.setup()
    }

    // MARK: - Header actions

    func fillWithRecommended() {
        let recommendedToFill = recommendedValidatorList
            .filter { !selectedValidatorList.contains($0) }
            .prefix(maxTargets - selectedValidatorList.count)

        guard !recommendedToFill.isEmpty else { return }

        selectedValidatorList.append(contentsOf: recommendedToFill)
        provideViewModels()
    }

    func clearFilter() {
        filter = CustomValidatorListFilter.defaultFilter()
        provideViewModels()
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
        guard var viewModel = viewModel else { return }

        let changedValidator = filteredValidatorList[index]

        guard !changedValidator.blocked else {
            wireframe.present(
                message: R.string.localizable
                    .stakingCustomBlockedWarning(preferredLanguages: selectedLocale.rLanguages),
                title: R.string.localizable
                    .commonWarning(preferredLanguages: selectedLocale.rLanguages),
                closeAction: R.string.localizable
                    .commonClose(preferredLanguages: selectedLocale.rLanguages),
                from: view
            )
            return
        }

        if let selectedIndex = selectedValidatorList.firstIndex(of: changedValidator) {
            selectedValidatorList.remove(at: selectedIndex)
            viewModel.selectedValidatorsCount -= 1
        } else {
            selectedValidatorList.append(changedValidator)
            viewModel.selectedValidatorsCount += 1
        }

        viewModel.cellViewModels[index].isSelected = !viewModel.cellViewModels[index].isSelected
        viewModel.selectedValidatorsCount = selectedValidatorList.count
        self.viewModel = viewModel

        view?.reload(viewModel, at: [index])
    }

    // MARK: - Presenting actions

    func didSelectValidator(at index: Int) {
        let selectedValidator = filteredValidatorList[index]

        let validatorInfo = SelectedValidatorInfo(
            address: selectedValidator.address,
            identity: selectedValidator.identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: selectedValidator.nominators,
                totalStake: selectedValidator.totalStake,
                stakeReturn: selectedValidator.stakeReturn,
                maxNominatorsRewarded: selectedValidator.maxNominatorsRewarded
            )
        )

        wireframe.present(validatorInfo, from: view)
    }

    func presentFilter() {
        wireframe.presentFilters(
            from: view,
            filter: filter,
            delegate: self
        )
    }

    func presentSearch() {
        wireframe.presentSearch(
            from: view,
            allValidators: electedValidatorList,
            selectedValidators: selectedValidatorList,
            delegate: self
        )
    }

    func proceed() {
        wireframe.proceed(
            from: view,
            validators: selectedValidatorList,
            maxTargets: maxTargets,
            delegate: self
        )
    }
}

// MARK: - CustomValidatorListInteractorOutputProtocol

extension CustomValidatorListPresenter: CustomValidatorListInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideValidatorListViewModel()

        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }
}

// MARK: - SelectedValidatorListDelegate

extension CustomValidatorListPresenter: SelectedValidatorListDelegate {
    func didRemove(_ validator: ElectedValidatorInfo) {
        if let displayedIndex = filteredValidatorList.firstIndex(of: validator) {
            changeValidatorSelection(at: displayedIndex)
        } else if let selectedIndex = selectedValidatorList.firstIndex(of: validator) {
            selectedValidatorList.remove(at: selectedIndex)
        }
    }
}

// MARK: - ValidatorListFilterDelegate

extension CustomValidatorListPresenter: ValidatorListFilterDelegate {
    func didUpdate(_ filter: CustomValidatorListFilter) {
        self.filter = filter
        provideViewModels()
    }
}

// MARK: - ValidatorSearchDelegate

extension CustomValidatorListPresenter: ValidatorSearchDelegate {
    func didUpdate(
        _ validators: [ElectedValidatorInfo],
        selectedValidatos: [ElectedValidatorInfo]
    ) {
        electedValidatorList = validators
        selectedValidatorList = selectedValidatos

        provideViewModels()
    }
}

// MARK: - Localizable

extension CustomValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
