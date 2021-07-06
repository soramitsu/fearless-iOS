import SoraFoundation
import CommonWallet

final class ValidatorListFilterPresenter {
    weak var view: ValidatorListFilterViewProtocol?
    weak var delegate: ValidatorListFilterDelegate?

    let wireframe: ValidatorListFilterWireframeProtocol
    let viewModelFactory: ValidatorListFilterViewModelFactoryProtocol

    let asset: WalletAsset
    let initialFilter: CustomValidatorListFilter
    private(set) var currentFilter: CustomValidatorListFilter

    init(
        wireframe: ValidatorListFilterWireframeProtocol,
        viewModelFactory: ValidatorListFilterViewModelFactoryProtocol,
        asset: WalletAsset,
        filter: CustomValidatorListFilter,
        localizationManager: LocalizationManager
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.asset = asset
        initialFilter = filter
        currentFilter = filter
        self.localizationManager = localizationManager
    }

    private func provideViewModels() {
        let viewModel = viewModelFactory.createViewModel(
            from: currentFilter,
            initialFilter: initialFilter,
            token: asset.symbol,
            locale: selectedLocale
        )
        view?.didUpdateViewModel(viewModel)
    }
}

extension ValidatorListFilterPresenter: ValidatorListFilterPresenterProtocol {
    func setup() {
        provideViewModels()
    }

    func toggleFilterItem(at index: Int) {
        guard let filter = ValidatorListFilterRow(rawValue: index) else {
            return
        }

        switch filter {
        case .withoutIdentity:
            currentFilter.allowsNoIdentity = !currentFilter.allowsNoIdentity
        case .slashed:
            currentFilter.allowsSlashed = !currentFilter.allowsSlashed
        case .oversubscribed:
            currentFilter.allowsOversubscribed = !currentFilter.allowsOversubscribed
        case .clusterLimit:
            let allowsUnlimitedClusters = currentFilter.allowsClusters == .unlimited
            currentFilter.allowsClusters = allowsUnlimitedClusters ?
                .limited(amount: StakingConstants.targetsClusterLimit) :
                .unlimited
        }

        provideViewModels()
    }

    func selectFilterItem(at index: Int) {
        guard let sortRow = ValidatorListSortRow(rawValue: index) else {
            return
        }

        currentFilter.sortedBy = sortRow.sortCriterion
        provideViewModels()
    }

    func applyFilter() {
        delegate?.didUpdate(currentFilter)
        wireframe.close(view)
    }

    func resetFilter() {
        currentFilter = CustomValidatorListFilter.recommendedFilter()
        provideViewModels()
    }
}

extension ValidatorListFilterPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
