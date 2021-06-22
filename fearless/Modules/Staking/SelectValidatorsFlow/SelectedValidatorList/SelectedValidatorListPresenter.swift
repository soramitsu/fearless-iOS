import SoraFoundation

final class SelectedValidatorListPresenter {
    weak var view: SelectedValidatorListViewProtocol?
    weak var delegate: SelectedValidatorListDelegate?

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

    private func selectedValidatorInfo(from validator: ElectedValidatorInfo) -> SelectedValidatorInfo {
        SelectedValidatorInfo(
            address: validator.address,
            identity: validator.identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: validator.nominators,
                totalStake: validator.totalStake,
                stakeReturn: validator.stakeReturn,
                maxNominatorsRewarded: validator.maxNominatorsRewarded
            )
        )
    }
}

// MARK: - SelectedValidatorListPresenterProtocol

extension SelectedValidatorListPresenter: SelectedValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func didSelectValidator(at index: Int) {
        let validatorInfo = selectedValidatorInfo(
            from: selectedValidatorList[index]
        )
        wireframe.present(validatorInfo, from: view)
    }

    func removeItem(at index: Int) {
        let validator = selectedValidatorList[index]
        delegate?.didRemove(validator)

        selectedValidatorList.remove(at: index)
        let viewModel = createViewModel()
        self.viewModel = viewModel

        view?.updateViewModel(viewModel)
        view?.didRemoveItem(at: index)
    }

    func proceed() {
        let validators = selectedValidatorList.map {
            selectedValidatorInfo(from: $0)
        }

        wireframe.proceed(
            from: view,
            targets: validators,
            maxTargets: maxTargets
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
