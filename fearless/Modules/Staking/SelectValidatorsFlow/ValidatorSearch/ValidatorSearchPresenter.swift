import SoraFoundation
import IrohaCrypto
import SSFModels

final class ValidatorSearchPresenter {
    weak var view: ValidatorSearchViewProtocol?

    let wireframe: ValidatorSearchWireframeProtocol
    let interactor: ValidatorSearchInteractorInputProtocol
    let viewModelFactory: ValidatorSearchViewModelFactoryProtocol
    var viewModelState: ValidatorSearchViewModelState
    let logger: LoggerProtocol?
    let chainAsset: ChainAsset

    private let wallet: MetaAccountModel

    private var isSearching: Bool = false

    init(
        wireframe: ValidatorSearchWireframeProtocol,
        interactor: ValidatorSearchInteractorInputProtocol,
        viewModelFactory: ValidatorSearchViewModelFactoryProtocol,
        viewModelState: ValidatorSearchViewModelState,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.logger = logger
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func provideViewModels() {
        guard !viewModelState.searchString.isEmpty else {
            viewModelState.reset()
            view?.didReset()
            return
        }

        guard let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            locale: selectedLocale
        ) else {
            viewModelState.updateViewModel(nil)
            view?.didReset()
            return
        }

        viewModelState.updateViewModel(viewModel)
        view?.didReload(viewModel)
    }

    private func performFullAddressSearch(by address: AccountAddress, accountId: AccountId) {
        viewModelState.performFullAddressSearch(by: address, accountId: accountId)
    }

    private func performSearch() {
        guard !viewModelState.searchString.isEmpty else {
            provideViewModels()
            return
        }

        if let accountId = try? AddressFactory.accountId(
            from: viewModelState.searchString,
            chain: chainAsset.chain
        ) {
            performFullAddressSearch(by: viewModelState.searchString, accountId: accountId)
            return
        }

        isSearching = true
        viewModelState.performSearch()
    }
}

extension ValidatorSearchPresenter: ValidatorSearchPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        provideViewModels()
    }

    // MARK: - Cell actions

    func changeValidatorSelection(at index: Int) {
        viewModelState.changeValidatorSelection(at: index)
    }

    // MARK: - Search actions

    func search(for textEntry: String) {
        viewModelState.searchString = textEntry

        if isSearching {
            view?.didStopSearch()
            isSearching = false
        }

        performSearch()
    }

    // MARK: - Presenting actions

    func didSelectValidator(at index: Int) {
        guard let flow = viewModelState.validatorInfoFlow(index: index) else {
            return
        }

        wireframe.present(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func applyChanges() {
        viewModelState.applyChanges()

        wireframe.close(view)
    }
}

extension ValidatorSearchPresenter: ValidatorSearchInteractorOutputProtocol {}

extension ValidatorSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            performSearch()
        }
    }
}

extension ValidatorSearchPresenter: ValidatorSearchModelStateListener {
    func viewModelChanged(_ viewModel: ValidatorSearchViewModel) {
        view?.didReload(viewModel)
    }

    func modelStateDidChanged(viewModelState _: ValidatorSearchViewModelState) {
        guard isSearching == true else { return }
        isSearching = false

        provideViewModels()
    }

    func didStartLoading() {
        view?.didStartSearch()
    }

    func didStopLoading() {
        view?.didStopSearch()
    }

    func didReceiveError(error _: Error) {
        viewModelState.updateViewModel(nil)
        view?.didReset()
    }

    func didNotFoundLocalValidator(accountId: AccountId) {
        isSearching = true
        view?.didStartSearch()
        interactor.performValidatorSearch(accountId: accountId)
    }
}
