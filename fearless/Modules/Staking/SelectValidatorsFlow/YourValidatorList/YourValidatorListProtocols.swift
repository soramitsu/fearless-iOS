import SoraFoundation

protocol YourValidatorListViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func reload(state: YourValidatorListViewState)
}

protocol YourValidatorListPresenterProtocol: AnyObject {
    func retry()
    func didSelectValidator(viewModel: YourValidatorViewModel)
    func changeValidators()
    func didLoad(view: YourValidatorListViewProtocol)
    func willAppear(view: YourValidatorListViewProtocol)
}

protocol YourValidatorListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol YourValidatorListInteractorOutputProtocol: AnyObject {}

protocol YourValidatorListWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: YourValidatorListViewProtocol?
    )

    func proceedToSelectValidatorsStart(
        from view: YourValidatorListViewProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: SelectValidatorsStartFlow
    )
}
