import SoraFoundation

final class SelectedValidatorListPresenter {
    weak var view: SelectedValidatorListViewProtocol?

    let wireframe: SelectedValidatorListWireframeProtocol
    let viewModelFactory: SelectedValidatorListViewModelFactory
    let maxTargets: Int

    private var selectedValidatorList: [ElectedValidatorInfo]
    private var viewModel: SelectedValidatorListViewModel?

    init(
        wireframe: SelectedValidatorListWireframeProtocol,
        viewModelFactory: SelectedValidatorListViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        selectedValidators: [ElectedValidatorInfo],
        maxTargets: Int
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        selectedValidatorList = selectedValidators
        self.maxTargets = maxTargets
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func createViewModel() -> SelectedValidatorListViewModel {
        viewModelFactory.createViewModel(
            from: selectedValidatorList,
            totalValidatorsCount: maxTargets,
            locale: selectedLocale
        )
    }

    private func provideViewModel() {
        let viewModel = createViewModel()
        self.viewModel = viewModel
        view?.reload(viewModel)
    }
}

// MARK: - SelectedValidatorListPresenterProtocol

extension SelectedValidatorListPresenter: SelectedValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func didSelectValidator(at index: Int) {
        let selectedValidator = selectedValidatorList[index]

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

    func removeItem(at index: Int) {
        selectedValidatorList.remove(at: index)
        let viewModel = createViewModel()
        self.viewModel = viewModel

        view?.updateViewModel(viewModel)
        view?.didRemoveItem(at: index)
    }

    func proceed() {
        #warning("Not implemented")
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
