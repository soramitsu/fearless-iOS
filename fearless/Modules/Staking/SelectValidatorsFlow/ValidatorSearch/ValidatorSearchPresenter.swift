import SoraFoundation
import IrohaCrypto

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

    private lazy var addressFactory = SS58AddressFactory()

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

    // MARK: - Private functions

    private func provideViewModels() {
        guard !searchString.isEmpty else {
            filteredValidatorList = []
            viewModel = nil
            view?.didReset()
            return
        }

        performSearch()
    }

    private func performAddressSearch() {
        filteredValidatorList = []

        let searchResult = allValidatorList.first {
            $0.address == searchString
        }

        if let validator = searchResult {
            filteredValidatorList.append(validator)
        }

        let viewModel = viewModelFactory.createViewModel(
            from: filteredValidatorList,
            selectedValidators: selectedValidatorList,
            locale: selectedLocale
        )

        self.viewModel = viewModel
        view?.didReload(viewModel)
    }

    private func performSearch() {
        if (try? addressFactory.accountId(from: searchString)) != nil {
            performAddressSearch()
            return
        }

        let searchString = self.searchString.lowercased()

        filteredValidatorList = allValidatorList.filter {
            $0.identity?.displayName.lowercased()
                .contains(searchString) ?? false
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
        provideViewModels()
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
            provideViewModels()
        }
    }
}
