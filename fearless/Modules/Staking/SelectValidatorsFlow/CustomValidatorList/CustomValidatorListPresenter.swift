import Foundation

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let viewModelFactory: CustomValidatorListViewModelFactory
    let maxTargets: Int

    private let electedValidators: [ElectedValidatorInfo]
    private var filteredValidators: [ElectedValidatorInfo] = []
    private var selectedValidators: Set<ElectedValidatorInfo> = []
    private var viewModel: [CustomValidatorCellViewModel] = []
    private var filter = CustomValidatorListFilter.recommendedFilter()

    init(
        interactor: CustomValidatorListInteractorInputProtocol,
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactory,
        electedValidators: [ElectedValidatorInfo],
        maxTargets: Int
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.electedValidators = electedValidators
        self.maxTargets = maxTargets
    }

    private func composeFilteredValidatorList() {
        let composer = CustomValidatorListComposer(filter: filter)

        filteredValidators = composer.compose(from: electedValidators)
    }

    private func createValidatorListViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            validators: filteredValidators,
            selectedValidators: selectedValidators
        )

        self.viewModel = viewModel
        view?.reload(viewModel)
    }

    private func createFilterButtonViewModel() {
        let emptyFilter = CustomValidatorListFilter.defaultFilter()
        let appliedState = filter != emptyFilter

        view?.setFilterAppliedState(to: appliedState)
    }
}

extension CustomValidatorListPresenter: CustomValidatorListPresenterProtocol {
    func setup() {
        composeFilteredValidatorList()
        createValidatorListViewModel()
        createFilterButtonViewModel()
    }

    func changeValidatorSelection(at index: Int) {
        let changedValidator = filteredValidators[index]

        if selectedValidators.contains(changedValidator) {
            selectedValidators.remove(changedValidator)
        } else {
            selectedValidators.insert(changedValidator)
        }

        viewModel[index].isSelected = !viewModel[index].isSelected

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

        composeFilteredValidatorList()
        createValidatorListViewModel()
        createFilterButtonViewModel()
    }

    func deselectAll() {
        var indexes: [Int] = []

        viewModel = viewModel.enumerated().map { index, item in
            var newItem = item

            if newItem.isSelected {
                newItem.isSelected = false
                indexes.append(index)
            }

            return newItem
        }

        selectedValidators = []

        view?.reload(viewModel, at: indexes)
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
