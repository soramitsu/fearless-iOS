import SoraFoundation

final class SelectedValidatorListPresenter {
    weak var view: SelectedValidatorListViewProtocol?
    weak var delegate: SelectedValidatorListDelegate?

    let wireframe: SelectedValidatorListWireframeProtocol
    let viewModelFactory: SelectedValidatorListViewModelFactory
    let maxTargets: Int
    let asset: AssetModel
    let chain: ChainModel
    let selectedAccount: MetaAccountModel

    private var selectedValidatorList: [SelectedValidatorInfo]

    init(
        wireframe: SelectedValidatorListWireframeProtocol,
        viewModelFactory: SelectedValidatorListViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        selectedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.selectedValidatorList = selectedValidatorList
        self.maxTargets = maxTargets
        self.asset = asset
        self.chain = chain
        self.selectedAccount = selectedAccount
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
        view?.didReload(viewModel)
    }
}

// MARK: - SelectedValidatorListPresenterProtocol

extension SelectedValidatorListPresenter: SelectedValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func didSelectValidator(at index: Int) {
        let validatorInfo = selectedValidatorList[index]
        wireframe.present(
            validatorInfo,
            asset: asset,
            chain: chain,
            from: view,
            wallet: selectedAccount
        )
    }

    func removeItem(at index: Int) {
        let validator = selectedValidatorList[index]

        selectedValidatorList.remove(at: index)

        let viewModel = createViewModel()
        view?.didChangeViewModel(viewModel, byRemovingItemAt: index)

        delegate?.didRemove(validator)
    }

    func proceed() {
        wireframe.proceed(
            from: view,
            targets: selectedValidatorList,
            maxTargets: maxTargets,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
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
