import Foundation
import SoraFoundation

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let viewModelFactory: CustomValidatorListViewModelFactory
    let maxTargets: Int

    private let electedValidators: [ElectedValidatorInfo]
    private let recommendedValidatorList: [ElectedValidatorInfo]

    private var filteredValidators: [ElectedValidatorInfo] = []
    private var selectedValidatorList: Set<ElectedValidatorInfo> = []
    private var viewModel: CustomValidatorListViewModel?
    private var filter = CustomValidatorListFilter.recommendedFilter()

    init(
        interactor: CustomValidatorListInteractorInputProtocol,
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        electedValidators: [ElectedValidatorInfo],
        recommendedValidators: [ElectedValidatorInfo],
        maxTargets: Int
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.electedValidators = electedValidators
        recommendedValidatorList = recommendedValidators
        self.maxTargets = maxTargets
        self.localizationManager = localizationManager
    }

    private func composeFilteredValidatorList() -> [ElectedValidatorInfo] {
        let composer = CustomValidatorListComposer(filter: filter)
        return composer.compose(from: electedValidators)
    }

    private func updateFilteredValidatorsList() {
        filteredValidators = composeFilteredValidatorList()
    }

    private func provideValidatorListViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            from: filteredValidators,
            selectedValidators: selectedValidatorList,
            totalValidatorsCount: electedValidators.count,
            filter: filter,
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
}

extension CustomValidatorListPresenter: CustomValidatorListPresenterProtocol {
    func setup() {
        provideViewModels()
    }

    func changeValidatorSelection(at index: Int) {
        guard var viewModel = viewModel else { return }

        let changedValidator = filteredValidators[index]

        if selectedValidatorList.contains(changedValidator) {
            selectedValidatorList.remove(changedValidator)
        } else {
            selectedValidatorList.insert(changedValidator)
        }

        viewModel.cellViewModels[index].isSelected = !viewModel.cellViewModels[index].isSelected
        self.viewModel = viewModel

        view?.reload(viewModel, at: [index])
    }

    func presentFilter() {
        #warning("Not implemented")
    }

    func presentSearch() {
        #warning("Not implemented")
    }

    func clearFilter() {
        filter = CustomValidatorListFilter.defaultFilter()
        provideViewModels()
    }

    func deselectAll() {
        guard var viewModel = viewModel else { return }
        var indexes: [Int] = []

        viewModel.cellViewModels =
            viewModel.cellViewModels.enumerated().map { index, item in
                var newItem = item

                if newItem.isSelected {
                    newItem.isSelected = false
                    indexes.append(index)
                }

                return newItem
            }

        selectedValidatorList = []

        self.viewModel = viewModel

        view?.reload(viewModel, at: indexes)
    }

    func fillWithRecommended() {
        var index = 0
        while index < recommendedValidatorList.count,
              selectedValidatorList.count < maxTargets {
            let recommendedValidator = recommendedValidatorList[index]

            if !selectedValidatorList.contains(recommendedValidator) {
                if let index = filteredValidators.firstIndex(of: recommendedValidator) {
                    changeValidatorSelection(at: index)
                }
            }

            index += 1
        }
    }

    func didSelectValidator(at index: Int) {
        let validator = electedValidators[index]
        let selectedValidator = SelectedValidatorInfo(
            address: validator.address,
            identity: validator.identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: validator.nominators,
                totalStake: validator.totalStake,
                stakeReturn: validator.stakeReturn,
                maxNominatorsRewarded: validator.maxNominatorsRewarded
            )
        )
        wireframe.present(selectedValidator, from: view)
    }
}

extension CustomValidatorListPresenter: CustomValidatorListInteractorOutputProtocol {}

extension CustomValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
