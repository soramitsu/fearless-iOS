import SoraFoundation

protocol ValidatorSearchWireframeProtocol: AlertPresentable {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        asset: AssetModel,
        chain: ChainModel,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    )

    func close(_ view: ControllerBackedProtocol?)
}

protocol ValidatorSearchDelegate: AnyObject {
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo])
}

protocol ValidatorSearchViewProtocol: ControllerBackedProtocol, Localizable {
    func didReload(_ viewModel: ValidatorSearchViewModel)
    func didStartSearch()
    func didStopSearch()
    func didReset()
}

protocol ValidatorSearchInteractorInputProtocol {
    func performValidatorSearch(accountId: AccountId)
}

protocol ValidatorSearchInteractorOutputProtocol: AnyObject {
    func didReceiveValidatorInfo(result: Result<SelectedValidatorInfo?, Error>)
}

protocol ValidatorSearchPresenterProtocol: Localizable {
    func setup()
    func changeValidatorSelection(at index: Int)
    func search(for textEntry: String)
    func didSelectValidator(at index: Int)
    func applyChanges()
}

protocol ValidatorSearchViewFactoryProtocol {
    static func createView(
        asset: AssetModel,
        chain: ChainModel,
        with fullValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?,
        wallet: MetaAccountModel
    ) -> ValidatorSearchViewProtocol?
}

protocol ValidatorSearchViewModelFactoryProtocol {
    func createViewModel(
        from displayValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> ValidatorSearchViewModel
}
