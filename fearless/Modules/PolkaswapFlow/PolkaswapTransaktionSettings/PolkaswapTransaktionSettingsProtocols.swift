typealias PolkaswapTransaktionSettingsModuleCreationResult = (
    view: PolkaswapTransaktionSettingsViewInput,
    input: PolkaswapTransaktionSettingsModuleInput
)

protocol PolkaswapTransaktionSettingsViewInput: ControllerBackedProtocol {
    func didReceive(market: LiquiditySourceType)
    func didReceive(viewModel: SlippageToleranceViewModel)
}

protocol PolkaswapTransaktionSettingsViewOutput: AnyObject {
    func didLoad(view: PolkaswapTransaktionSettingsViewInput)
    func didTapSelectMarket()
    func didChangeSlider(value: Float)
    func didTapBackButton()
    func didTapResetButton()
    func didTapSaveButton()
}

protocol PolkaswapTransaktionSettingsInteractorInput: AnyObject {
    func setup(with output: PolkaswapTransaktionSettingsInteractorOutput)
}

protocol PolkaswapTransaktionSettingsInteractorOutput: AnyObject {}

protocol PolkaswapTransaktionSettingsRouterInput: PresentDismissable, SheetAlertPresentable {
    func showSelectMarket(
        from view: ControllerBackedProtocol?,
        markets: [LiquiditySourceType],
        moduleOutput: SelectMarketModuleOutput?
    )
}

protocol PolkaswapTransaktionSettingsModuleInput: AnyObject {}

protocol PolkaswapTransaktionSettingsModuleOutput: AnyObject {
    func didReceive(market: LiquiditySourceType, slippadgeTolerance: Float)
}
