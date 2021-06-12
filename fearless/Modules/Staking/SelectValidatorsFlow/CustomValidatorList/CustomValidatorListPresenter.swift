import Foundation

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let viewModelFactory: CustomValidatorListViewModelFactory

    private let electedValidators: [ElectedValidatorInfo]
    private var filteredValidators: [ElectedValidatorInfo] = []
    private var selectedValidators: Set<ElectedValidatorInfo> = []
    private var viewModel: [CustomValidatorCellViewModel] = []
    private var filter = CustomValidatorListFilter.recommendedFilter()

    init(
        interactor: CustomValidatorListInteractorInputProtocol,
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactory,
        validators: [ElectedValidatorInfo]
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        electedValidators = validators
    }

    private func composeFilteredValidatorList() {
        let composer = CustomValidatorListComposer(filter: filter)

        filteredValidators = composer.compose(from: electedValidators)
    }

    private func createValidatorListViewModel() {
        let viewModel = viewModelFactory.createViewModel(validators: filteredValidators)
        view?.reload(with: viewModel)
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
