import Foundation
import SoraFoundation

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let viewModelFactory: CustomValidatorListViewModelFactory
    let maxTargets: Int
    let logger: LoggerProtocol?

    private let electedValidatorList: [ElectedValidatorInfo]
    private let recommendedValidatorList: [ElectedValidatorInfo]

    private var filteredValidatorList: [ElectedValidatorInfo] = []
    private var selectedValidatorSet: Set<ElectedValidatorInfo> = []
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
            selectedValidators: selectedValidatorSet,
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

        selectedValidatorSet = []

        self.viewModel = viewModel

        view?.reload(viewModel, at: indexes)
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
        var index = 0

        while index < recommendedValidatorList.count,
              selectedValidatorSet.count < maxTargets {
            let recommendedValidator = recommendedValidatorList[index]

            if !selectedValidatorSet.contains(recommendedValidator) {
                if let index = filteredValidatorList.firstIndex(of: recommendedValidator) {
                    changeValidatorSelection(at: index)
                }
            }

            index += 1
        }
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

        if selectedValidatorSet.contains(changedValidator) {
            selectedValidatorSet.remove(changedValidator)
        } else {
            selectedValidatorSet.insert(changedValidator)
        }

        viewModel.cellViewModels[index].isSelected = !viewModel.cellViewModels[index].isSelected
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
        #warning("Not implemented")
    }

    func presentSearch() {
        #warning("Not implemented")
    }

    func proceed() {
        #warning("Not implemented")
    }
}

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

extension CustomValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
