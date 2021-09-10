import SoraFoundation
import IrohaCrypto

final class ValidatorSearchPresenter {
    weak var view: ValidatorSearchViewProtocol?
    weak var delegate: ValidatorSearchDelegate?

    let wireframe: ValidatorSearchWireframeProtocol
    let interactor: ValidatorSearchInteractorInputProtocol
    let viewModelFactory: ValidatorSearchViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var fullValidatorList: [SelectedValidatorInfo]
    private var selectedValidatorList: [SelectedValidatorInfo]
    private var referenceValidatorList: [SelectedValidatorInfo]
    private var filteredValidatorList: [SelectedValidatorInfo] = []
    private var viewModel: ValidatorSearchViewModel?
    private var searchString: String = ""
    private var isSearching: Bool = false

    private lazy var addressFactory = SS58AddressFactory()

    init(
        wireframe: ValidatorSearchWireframeProtocol,
        interactor: ValidatorSearchInteractorInputProtocol,
        viewModelFactory: ValidatorSearchViewModelFactoryProtocol,
        fullValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.fullValidatorList = fullValidatorList
        self.selectedValidatorList = selectedValidatorList
        referenceValidatorList = selectedValidatorList
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

        let viewModel = viewModelFactory.createViewModel(
            from: filteredValidatorList,
            selectedValidatorList: selectedValidatorList,
            locale: selectedLocale
        )

        self.viewModel = viewModel
        view?.didReload(viewModel)
    }

    private func performFullAddressSearch(by address: AccountAddress, accountId: AccountId) {
        filteredValidatorList = []

        let searchResult = fullValidatorList.first {
            $0.address == address
        }

        guard let validator = searchResult else {
            isSearching = true
            view?.didStartSearch()
            interactor.performValidatorSearch(accountId: accountId)
            return
        }

        filteredValidatorList.append(validator)

        provideViewModels()
    }

    private func performSearch() {
        guard !searchString.isEmpty else {
            provideViewModels()
            return
        }

        if let accountId = try? addressFactory.accountId(from: searchString) {
            performFullAddressSearch(by: searchString, accountId: accountId)
            return
        }

        let nameSearchString = searchString.lowercased()

        filteredValidatorList = fullValidatorList.filter {
            ($0.identity?.displayName.lowercased()
                .contains(nameSearchString) ?? false) ||
                $0.address.hasPrefix(searchString)
        }.sorted(by: {
            $0.stakeReturn > $1.stakeReturn
        })

        provideViewModels()
    }
}

extension ValidatorSearchPresenter: ValidatorSearchPresenterProtocol {
    func setup() {
        provideViewModels()
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

        let differsFromInitial = referenceValidatorList != selectedValidatorList

        viewModel.cellViewModels[index].isSelected = !viewModel.cellViewModels[index].isSelected
        viewModel.differsFromInitial = differsFromInitial

        self.viewModel = viewModel

        view?.didReload(viewModel)
    }

    // MARK: - Search actions

    func search(for textEntry: String) {
        searchString = textEntry

        if isSearching {
            view?.didStopSearch()
            isSearching = false
        }

        performSearch()
    }

    // MARK: - Presenting actions

    func didSelectValidator(at index: Int) {
        let selectedValidator = filteredValidatorList[index]
        wireframe.present(selectedValidator, from: view)
    }

    func applyChanges() {
        delegate?.validatorSearchDidUpdate(selectedValidatorList: selectedValidatorList)

        wireframe.close(view)
    }
}

extension ValidatorSearchPresenter: ValidatorSearchInteractorOutputProtocol {
    func didReceiveValidatorInfo(result: Result<SelectedValidatorInfo?, Error>) {
        view?.didStopSearch()

        guard isSearching == true else { return }
        isSearching = false

        if case let .failure(error) = result {
            logger?.error("Did receive validator info error: \(error)")
            return
        }

        guard case let .success(validator) = result,
              let validatorInfo = validator
        else {
            filteredValidatorList = []
            provideViewModels()
            return
        }

        fullValidatorList.append(validatorInfo)
        filteredValidatorList = [validatorInfo]
        provideViewModels()
    }
}

extension ValidatorSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            performSearch()
        }
    }
}
