import SoraFoundation

protocol StakingBalanceViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>)
}

protocol StakingBalanceViewModelFactoryProtocol {
    func createViewModel(from balanceData: StakingBalanceData) -> LocalizableResource<StakingBalanceViewModel>
}

protocol StakingBalancePresenterProtocol: AnyObject {
    func setup()
    func handleAction(_ action: StakingBalanceAction)
    func handleUnbondingMoreAction()
}

protocol StakingBalanceInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingBalanceInteractorOutputProtocol: AnyObject {
    func didReceive(ledgerResult: Result<StakingLedger?, Error>)
    func didReceive(activeEraResult: Result<EraIndex?, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(stashItemResult: Result<StashItem?, Error>)
    func didReceive(controllerResult: Result<ChainAccountResponse?, Error>)
    func didReceive(stashResult: Result<ChainAccountResponse?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
}

protocol StakingBalanceWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showBondMore(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )

    func showUnbond(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )

    func showRedeem(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )

    func showRebond(
        from view: ControllerBackedProtocol?,
        option: StakingRebondOption,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )

    func cancel(from view: ControllerBackedProtocol?)
}
