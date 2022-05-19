import SoraFoundation

protocol ValidatorSearchWireframeProtocol: AlertPresentable {
    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
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

protocol ValidatorSearchInteractorOutputProtocol: AnyObject {}

protocol ValidatorSearchPresenterProtocol: Localizable {
    func setup()
    func changeValidatorSelection(at index: Int)
    func search(for textEntry: String)
    func didSelectValidator(at index: Int)
    func applyChanges()
}

protocol ValidatorSearchViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        flow: ValidatorSearchFlow,
        delegate: ValidatorSearchDelegate?
    ) -> ValidatorSearchViewProtocol?
}

// protocol ValidatorSearchViewModelFactoryProtocol {
//    func createViewModel(
//        from displayValidatorList: [SelectedValidatorInfo],
//        selectedValidatorList: [SelectedValidatorInfo],
//        locale: Locale
//    ) -> ValidatorSearchViewModel
// }
