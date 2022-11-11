import SoraFoundation

protocol ValidatorSearchWireframeProtocol: SheetAlertPresentable {
    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func close(_ view: ControllerBackedProtocol?)
}

protocol ValidatorSearchRelaychainDelegate: AnyObject {
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo])
}

protocol ValidatorSearchParachainDelegate: AnyObject {
    func validatorSearchDidUpdate(selectedValidatorList: [ParachainStakingCandidateInfo])
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
        wallet: MetaAccountModel
    ) -> ValidatorSearchViewProtocol?
}
