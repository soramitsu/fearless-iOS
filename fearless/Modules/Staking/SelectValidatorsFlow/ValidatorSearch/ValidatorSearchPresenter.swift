import SoraFoundation

final class ValidatorSearchPresenter {
    weak var view: ValidatorSearchViewProtocol?
    weak var delegate: ValidatorSearchDelegate?

    let wireframe: ValidatorSearchWireframeProtocol
    let interactor: ValidatorSearchInteractorInputProtocol
    let viewModelFactory: ValidatorSearchViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var allValidatorList: [ElectedValidatorInfo] = []
    private var selectedValidatorList: [ElectedValidatorInfo] = []
    private var filteredValidatorList: [ElectedValidatorInfo] = []
    private var viewModel: ValidatorSearchViewModel?
    private var searchString: String = ""

    init(
        wireframe: ValidatorSearchWireframeProtocol,
        interactor: ValidatorSearchInteractorInputProtocol,
        viewModelFactory: ValidatorSearchViewModelFactoryProtocol,
        allValidators: [ElectedValidatorInfo],
        selectedValidators: [ElectedValidatorInfo],
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        allValidatorList = allValidators
        selectedValidatorList = selectedValidators
        self.logger = logger
        self.localizationManager = localizationManager
    }

    #warning("Not implemented")

    // MARK: - Private functions

    private func provideViewModels() {
        if searchString.isEmpty {
            filteredValidatorList = []
            let viewModel = viewModelFactory.createEmptyModel()
            self.viewModel = viewModel
            view?.didReload(viewModel)
        }

        performSearch()
    }

    private func performSearch() {
        let searchString = searchString.lowercased()

        filteredValidatorList = allValidatorList.filter {
            $0.identity?.displayName.lowercased()
                .contains(searchString) ?? false ||
                $0.address.lowercased()
                .contains(searchString)
        }.sorted(by: {
            $0.stakeReturn > $1.stakeReturn
        })

        let viewModel = viewModelFactory.createViewModel(
            from: filteredValidatorList,
            selectedValidators: selectedValidatorList,
            locale: selectedLocale
        )

        self.viewModel = viewModel
        view?.didReload(viewModel)
    }
}

extension ValidatorSearchPresenter: ValidatorSearchPresenterProtocol {
    func setup() {
        // TODO: provideViewModels()?
        interactor.setup()
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
        } else {
            selectedValidatorList.append(changedValidator)
        }

        viewModel.cellViewModels[index].isSelected = !viewModel.cellViewModels[index].isSelected
        self.viewModel = viewModel

        view?.didReload(viewModel)
    }

    // MARK: - Search actions

    func search(for textEntry: String) {
        searchString = textEntry
        provideViewModels()
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

    func applyChanges() {
        delegate?.didUpdate(
            allValidatorList,
            selectedValidatos: selectedValidatorList
        )

        wireframe.close(view)
    }
}

extension ValidatorSearchPresenter: ValidatorSearchInteractorOutputProtocol {
    #warning("Not implemented")
}

extension ValidatorSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            // TODO: provideViewModels()?
        }
    }
}
