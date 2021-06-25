import SoraFoundation

protocol YourValidatorsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(state: YourValidatorsViewState)
}

protocol YourValidatorsPresenterProtocol: AnyObject {
    func setup()
    func retry()
    func didSelectValidator(viewModel: YourValidatorViewModel)
    func changeValidators()
}

protocol YourValidatorsInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol YourValidatorsInteractorOutputProtocol: AnyObject {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveLedger(result: Result<StakingLedger?, Error>)
    func didReceiveRewardDestination(result: Result<RewardDestinationArg?, Error>)
}

protocol YourValidatorsWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func showValidatorInfo(
        from view: YourValidatorsViewProtocol?,
        validatorInfo: ValidatorInfoProtocol
    )

    func showRecommendedValidators(
        from view: YourValidatorsViewProtocol?,
        existingBonding: ExistingBonding
    )
}
